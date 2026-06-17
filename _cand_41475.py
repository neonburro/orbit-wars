import json, os
os.environ['OW_PARAMS'] = '{"reserve_ratio": 0.212, "reserve_ratio_late": 0.152, "leader_bonus": 0.075, "enemy_bonus": 0.594, "comet_bonus": 0.18, "prod_weight": 0.611, "inbound_thresh": 0.73, "overshoot": 2}'
import math
import os
import json

try:
    from kaggle_environments.envs.orbit_wars.orbit_wars import Planet, Fleet
except Exception:
    from collections import namedtuple
    Planet = namedtuple("Planet", "id owner x y radius ships production")
    Fleet = namedtuple("Fleet", "id owner x y angle from_planet_id ships")

CENTER_X = 50.0
CENTER_Y = 50.0
SUN_RADIUS = 10.0
MAX_SPEED = 6.0
ROTATION_LIMIT = 50.0
TOTAL_TURNS = 500

PARAMS = {
    "reserve_ratio": 0.20,
    "reserve_ratio_late": 0.30,
    "leader_bonus": 1.0,
    "enemy_bonus": 0.5,
    "comet_bonus": 0.6,
    "prod_weight": 1.0,
    "inbound_thresh": 0.9,
    "overshoot": 2,
}
_env = os.environ.get("OW_PARAMS")
if _env:
    try:
        PARAMS.update(json.loads(_env))
    except Exception:
        pass


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
    return dist(planet.x, planet.y, CENTER_X, CENTER_Y) + planet.radius < ROTATION_LIMIT


def rotate_point(x, y, theta):
    dx = x - CENTER_X
    dy = y - CENTER_Y
    c = math.cos(theta)
    s = math.sin(theta)
    return (CENTER_X + dx * c - dy * s, CENTER_Y + dx * s + dy * c)


def predict_position(planet, ang_vel, turns):
    if not is_orbiting(planet, ang_vel) or turns <= 0:
        return planet.x, planet.y
    return rotate_point(planet.x, planet.y, ang_vel * turns)


def path_crosses_sun(x0, y0, x1, y1):
    dx = x1 - x0
    dy = y1 - y0
    seg = dx * dx + dy * dy
    if seg == 0:
        return dist(x0, y0, CENTER_X, CENTER_Y) <= SUN_RADIUS
    t = ((CENTER_X - x0) * dx + (CENTER_Y - y0) * dy) / seg
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
        na = math.atan2(pty - src.y, ptx - src.x)
        tx, ty = ptx, pty
        if abs(na - angle) < 1e-4:
            angle = na
            break
        angle = na
    return angle, eta, tx, ty


def aim(sx, sy, dx, dy):
    return math.atan2(dy - sy, dx - sx)


def agent(obs):
    P = PARAMS
    moves = []
    player = _get(obs, "player", 0)
    ang_vel = _get(obs, "angular_velocity", 0.0) or 0.0
    comet_ids = set(_get(obs, "comet_planet_ids", []) or [])
    step = _get(obs, "step", 0) or 0
    planets = [Planet(*p) for p in _get(obs, "planets", [])]
    fleets = [Fleet(*f) for f in _get(obs, "fleets", [])]
    my_planets = [p for p in planets if p.owner == player]
    if not my_planets:
        return moves
    by_id = {p.id: p for p in planets}
    late_game = (step / float(TOTAL_TURNS)) > 0.75

    score_by_owner = {}
    for p in planets:
        if p.owner >= 0:
            score_by_owner[p.owner] = score_by_owner.get(p.owner, 0) + p.ships
    for f in fleets:
        if f.owner >= 0:
            score_by_owner[f.owner] = score_by_owner.get(f.owner, 0) + f.ships
    leader = None
    best = -1
    for o, sc in score_by_owner.items():
        if o != player and sc > best:
            leader = o
            best = sc

    my_inbound = {}
    for f in fleets:
        if f.owner != player:
            continue
        bp = None
        ba = -2.0
        for t in planets:
            if t.owner == player:
                continue
            d = dist(f.x, f.y, t.x, t.y)
            if d < 0.001:
                continue
            al = math.cos(math.atan2(t.y - f.y, t.x - f.x) - f.angle)
            if al > ba:
                ba = al
                bp = t.id
        if bp is not None and ba > P["inbound_thresh"]:
            my_inbound[bp] = my_inbound.get(bp, 0) + f.ships

    threat = {p.id: 0 for p in my_planets}
    for f in fleets:
        if f.owner == player:
            continue
        bp = None
        ba = -2.0
        for mp in my_planets:
            d = dist(f.x, f.y, mp.x, mp.y)
            if d < 0.001:
                continue
            al = math.cos(math.atan2(mp.y - f.y, mp.x - f.x) - f.angle)
            if al > ba:
                ba = al
                bp = mp.id
        if bp is not None and ba > 0.85:
            threat[bp] = threat.get(bp, 0) + f.ships

    reserve = {}
    ratio = P["reserve_ratio_late"] if late_game else P["reserve_ratio"]
    for mp in my_planets:
        t = threat.get(mp.id, 0)
        base = 2 if mp.id in comet_ids else max(2, int(mp.ships * ratio))
        reserve[mp.id] = max(base, t + 2 if t > 0 else base)

    targets = [p for p in planets if p.owner != player]
    if not targets:
        return moves
    my_avail = {mp.id: max(0, mp.ships - reserve[mp.id]) for mp in my_planets}

    plans = []
    for t in targets:
        is_comet = t.id in comet_ids
        contribs = []
        for mp in my_planets:
            a, eta, ptx, pty = lead_solution(mp, t, ang_vel, int(t.ships) + 1)
            if path_crosses_sun(mp.x, mp.y, ptx, pty):
                continue
            contribs.append((eta, mp.id, a, ptx, pty))
        if not contribs:
            continue
        contribs.sort()
        min_eta = contribs[0][0]
        defenders = t.ships + (min_eta * t.production if t.owner != -1 else 0)
        need = int(defenders) + P["overshoot"] - my_inbound.get(t.id, 0)
        if need <= 0:
            continue
        prod = t.production if t.production else 1
        score = (prod * P["prod_weight"]) / (min_eta + 1.0)
        if t.owner == leader and leader is not None:
            score += P["leader_bonus"]
        elif t.owner != -1:
            score += P["enemy_bonus"]
        if is_comet:
            score += P["comet_bonus"]
        plans.append((score, need, t, contribs))

    plans.sort(reverse=True, key=lambda x: x[0])
    used = dict(my_avail)
    for score, need, t, contribs in plans:
        committed = []
        got = 0
        for eta, pid, a, ptx, pty in contribs:
            if used.get(pid, 0) <= 1:
                continue
            spend = min(used[pid], need - got)
            if spend <= 0:
                break
            committed.append((pid, ptx, pty, spend))
            got += spend
            if got >= need:
                break
        if got < need:
            continue
        for pid, ptx, pty, spend in committed:
            mp = by_id[pid]
            if path_crosses_sun(mp.x, mp.y, ptx, pty):
                continue
            moves.append([pid, aim(mp.x, mp.y, ptx, pty), spend])
            used[pid] -= spend
    return moves
