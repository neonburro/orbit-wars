import sys, json
params = json.loads(sys.argv[1])
out = sys.argv[2]
header = "import json, os\nos.environ['OW_PARAMS'] = " + repr(json.dumps(params)) + "\n"
body = open('bot_param.py').read()
open(out, 'w').write(header + body)
