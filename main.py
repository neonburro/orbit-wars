import math

try:
    from kaggle_environments.envs.orbit_wars.orbit_wars import Planet, Fleet
except Exception:
    from collections import namedtuple
    Planet = namedtuple("Planet", "id owner x y radius ships production")
    Fleet = namedtuple("Fleet", "id owner x y angle from_planet_id ships")

CENTER_X = 50.0
CENTER_Y = 50.0
SUN_RADIUS = 10.0
BOARD = 100.0
MAX_SPEED = 6.0
ROTATION_LIMIT = 50.0


def _get(obs, key, default):
    if isinstance(obs, dict):
        return obs.get(key, default)
    return getattr(obs, key, default)


def fleet_speed(ships):
    if ships <= 1:
        return 1.0
    frac = (math.log(ships) / math.log(1000.0)) ** 1.5
    return 1.0 + (MAX_SPEED - 1.0) * min(frac, 1.0)


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def is_orbiting(planet, ang_vel):
    if ang_vel == 0:
        return False
    orbital_radius = dist(planet.x, planet.y, CENTER_X, CENTER_Y)
    return orbital_radius + planet.radius < ROTATION_LIMIT


def rotate_point(x, y, theta):
    dx = x - CENTER_X
    dy = y - CENTER_Y
    cos_t = math.cos(theta)
    sin_t = math.sin(theta)
    return (
        CENTER_X + dx * cos_t - dy * sin_t,
        CENTER_Y + dx * sin_t + dy * cos_t,
    )


def predict_position(planet, ang_vel, turns):
    if not is_orbiting(planet, ang_vel) or turns <= 0:
        return planet.x, planet.y
    return rotate_point(planet.x, planet.y, ang_vel * turns)


def path_crosses_sun(x0, y0, x1, y1):
    dx = x1 - x0
    dy = y1 - y0
    seg_len_sq = dx * dx + dy * dy
    if seg_len_sq == 0:
        return dist(x0, y0, CENTER_X, CENTER_Y) <= SUN_RADIUS
    t = ((CENTER_X - x0) * dx + (CENTER_Y - y0) * dy) / seg_len_sq
    t = max(0.0, min(1.0, t))
    cx = x0 + t * dx
    cy = y0 + t * dy
    return dist(cx, cy, CENTER_X, CENTER_Y) <= SUN_RADIUS + 0.5


def lead_solution(src, tgt, ang_vel, send_estimate, max_iter=10):
    tx, ty = tgt.x, tgt.y
    angle = math.atan2(ty - src.y, tx - src.x)
    eta = 1
    for _ in range(max_iter):
        d = dist(src.x, src.y, tx, ty)
        spd = fleet_speed(max(1, send_estimate))
        eta = max(1, int(math.ceil(d / spd)))
        ptx, pty = predict_position(tgt, ang_vel, eta)
        new_angle = math.atan2(pty - src.y, ptx - src.x)
        tx, ty = ptx, pty
        if abs(new_angle - angle) < 1e-4:
            angle = new_angle
            break
        angle = new_angle
    return angle, eta, tx, ty


def aim(src_x, src_y, dst_x, dst_y):
    return math.atan2(dst_y - src_y, dst_x - src_x)


def agent(obs):
    moves = []
    player = _get(obs, "player", 0)
    raw_planets = _get(obs, "planets", [])
    raw_fleets = _get(obs, "fleets", [])
    ang_vel = _get(obs, "angular_velocity", 0.0) or 0.0
    comet_ids = set(_get(obs, "comet_planet_ids", []) or [])

    planets = [Planet(*p) for p in raw_planets]
    fleets = [Fleet(*f) for f in raw_fleets]

    my_planets = [p for p in planets if p.owner == player]
    if not my_planets:
        return moves

    by_id = {p.id: p for p in planets}

    # Identify the strongest opponent for anti-leader targeting (4p relevance).
    score_by_owner = {}
    for p in planets:
        if p.owner >= 0:
            score_by_owner[p.owner] = score_by_owner.get(p.owner, 0) + p.ships
    for f in fleets:
        if f.owner >= 0:
            score_by_owner[f.owner] = score_by_owner.get(f.owner, 0) + f.ships
    leader = None
    leader_score = -1
    for owner, sc in score_by_owner.items():
        if owner != player and sc > leader_score:
            leader = owner
            leader_score = sc

    # Estimate enemy fleets inbound to each of OUR planets (defense).
    threat = {p.id: 0 for p in my_planets}
    for f in fleets:
        if f.owner == player:
            continue
        # Find which of our planets this fleet is most likely heading at.
        best_pid = None
        best_align = -2.0
        for mp in my_planets:
            d = dist(f.x, f.y, mp.x, mp.y)
            if d < 0.001:
                continue
            ang_to = math.atan2(mp.y - f.y, mp.x - f.x)
            align = math.cos(ang_to - f.angle)
            if align > best_align:
                best_align = align
                best_pid = mp.id
        if best_pid is not None and best_align > 0.85:
            threat[best_pid] = threat.get(best_pid, 0) + f.ships

    # Reserve ships at threatened planets so we do not lose them.
    reserve = {}
    for mp in my_planets:
        t = threat.get(mp.id, 0)
        base = 2 if mp.id in comet_ids else max(2, int(mp.ships * 0.20))
        reserve[mp.id] = max(base, t + 1 if t > 0 else base)

    targets = [p for p in planets if p.owner != player]
    if not targets:
        return moves

    # Build a global ranked list of (target, attacker, plan) opportunities,
    # then allow multiple of our planets to combine on one strong target.
    my_avail = {mp.id: max(0, mp.ships - reserve[mp.id]) for mp in my_planets}

    target_plans = []
    for t in targets:
        is_comet = t.id in comet_ids
        contributions = []
        for mp in my_planets:
            send_est = int(t.ships) + 1
            angle, eta, ptx, pty = lead_solution(mp, t, ang_vel, send_est)
            if path_crosses_sun(mp.x, mp.y, ptx, pty):
                continue
            contributions.append((eta, mp.id, angle, ptx, pty))
        if not contributions:
            continue
        contributions.sort()  # nearest first
        min_eta = contributions[0][0]
        defenders = t.ships
        if t.owner != -1:
            defenders += min_eta * t.production
        need = int(defenders) + 2

        prod = t.production if t.production else 1
        score = prod / (min_eta + 1.0)
        if t.owner == leader and leader is not None:
            score += 1.0  # prioritize hurting the leader
        elif t.owner != -1:
            score += 0.5  # enemy planet over neutral
        if is_comet:
            score += 0.6  # comets are free production, grab them
        target_plans.append((score, need, min_eta, t, contributions))

    target_plans.sort(reverse=True, key=lambda x: x[0])

    used = dict(my_avail)
    for score, need, min_eta, t, contributions in target_plans:
        # Try to assemble `need` ships from the closest available planets.
        committed = []
        gathered = 0
        for eta, pid, angle, ptx, pty in contributions:
            if used.get(pid, 0) <= 1:
                continue
            # Re-aim from this planet to where target sits at the lead ETA.
            spend = min(used[pid], need - gathered)
            if spend <= 0:
                break
            committed.append((pid, ptx, pty, spend))
            gathered += spend
            if gathered >= need:
                break
        if gathered < need:
            continue  # cannot take it this turn, skip
        for pid, ptx, pty, spend in committed:
            mp = by_id[pid]
            angle = aim(mp.x, mp.y, ptx, pty)
            if path_crosses_sun(mp.x, mp.y, ptx, pty):
                continue
            moves.append([pid, angle, spend])
            used[pid] -= spend

    return moves