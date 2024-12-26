"""
Setup steps:
- Install protoc
- git clone --depth 1 https://github.com/google/cel-spec.git
- git clone --depth 1 https://github.com/googleapis/googleapis.git
- protoc -Icel-spec/proto -Igoogleapis --python_out=. cel-spec/proto/cel/expr/*.proto cel-spec/proto/cel/expr/conformance/**/*.proto googleapis/google/rpc/status.proto
"""

import glob
import os
from cel.expr.conformance.test import simple_pb2
import cel.expr.conformance.proto2.test_all_types_extensions_pb2
import cel.expr.conformance.proto3.test_all_types_pb2
from google.protobuf import json_format, text_format

if not os.path.exists("testdata"):
    os.mkdir("testdata")

for path in glob.glob("cel-spec/tests/simple/testdata/*.textproto"):
    with open(path) as f:
        message = text_format.Parse(f.read(), simple_pb2.SimpleTestFile())
        json = json_format.MessageToJson(message)

        out_path = "testdata/" + os.path.basename(path).replace(".textproto", ".json")
        with open(out_path, "w") as out:
            out.write(json)