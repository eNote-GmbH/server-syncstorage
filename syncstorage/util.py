# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this file,
# You can obtain one at http://mozilla.org/MPL/2.0/.

import time
from datetime import datetime
import decimal
import logging
import simplejson
import socket

from mozsvc.util import safer_format_traceback

TWO_DECIMAL_PLACES = decimal.Decimal("1.00")


def get_timestamp(value=None):
    """Transforms a python time value into a syncstorage timestamp."""
    if value is None:
        value = time.time()
    try:
        if not isinstance(value, decimal.Decimal):
            value = decimal.Decimal(str(value))
        return value.quantize(TWO_DECIMAL_PLACES,
                              rounding=decimal.ROUND_CEILING)
    except decimal.InvalidOperation, e:
        raise ValueError(str(e))


def json_dumps(value):
    """Decimal-aware version of json.dumps()."""
    return simplejson.dumps(value, use_decimal=True)


def json_loads(value):
    """Decimal-aware version of json.loads()."""
    return simplejson.loads(value, use_decimal=True)


class JsonLogFormatter(logging.Formatter):
    """Log formatter that outputs machine-readable json.

    This log formatter outputs JSON format messages that are compatible with
    Mozilla's standard heka-based log aggregation infrastructure.  It ignores
    any user-specific message and instead outouts a JSON dict of all relevant
    log-record attributes.

    Original version at:
    https://github.com/mozilla-services/mozservices/blob/master/mozsvc/util.py
    """

    DEFAULT_LOGRECORD_ATTRS = set((
        'args', 'asctime', 'created', 'exc_info', 'exc_text', 'filename',
        'funcName', 'levelname', 'levelno', 'lineno', 'module', 'msecs',
        'message', 'msg', 'name', 'pathname', 'process', 'processName',
        'relativeCreated', 'thread', 'threadName'
    ))

    DEFAULT_DETAILS = {
        "v": 1,
        "hostname": socket.gethostname(),
    }

    def format(self, record):
        # Take default values from the record and the environment.
        details = self.DEFAULT_DETAILS.copy()
        details.update({
            "op": record.name,
            "name": record.name,
            "time": datetime.utcfromtimestamp(record.created).isoformat()+"Z",
            "pid": record.process,
            "level": record.levelname,
        })
        # Include any custom attributes set on the record.
        # These would usually be collected metrics data.
        for key, value in record.__dict__.iteritems():
            if key not in self.DEFAULT_LOGRECORD_ATTRS:
                details[key] = value
        # Only include the 'message' key if it has useful content
        # and is not already a JSON blob.
        message = record.getMessage()
        if message:
            if not message.startswith("{") and not message.endswith("}"):
                details["message"] = message
        # If there is an error, format it for nice output.
        if record.exc_info is not None:
            details["error"] = repr(record.exc_info[1])
            details["traceback"] = safer_format_traceback(*record.exc_info)
        return json_dumps(details)
