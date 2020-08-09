# The gunicorn "configuration" file

import cProfile

profile = cProfile.Profile()

def pre_request(worker, req):
    profile.enable()

def post_request(worker, req, *args):
    profile.disable()

def worker_exit(server, worker):
    profile.dump_stats("local/syncstorage.pstats")
