# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: cel/expr/checked.proto

require 'google/protobuf'

require 'cel/expr/syntax_pb'
require 'google/protobuf/empty_pb'
require 'google/protobuf/struct_pb'


descriptor_data = "\n\x16\x63\x65l/expr/checked.proto\x12\x08\x63\x65l.expr\x1a\x15\x63\x65l/expr/syntax.proto\x1a\x1bgoogle/protobuf/empty.proto\x1a\x1cgoogle/protobuf/struct.proto\"\xec\x02\n\x0b\x43heckedExpr\x12>\n\rreference_map\x18\x02 \x03(\x0b\x32\'.cel.expr.CheckedExpr.ReferenceMapEntry\x12\x34\n\x08type_map\x18\x03 \x03(\x0b\x32\".cel.expr.CheckedExpr.TypeMapEntry\x12)\n\x0bsource_info\x18\x05 \x01(\x0b\x32\x14.cel.expr.SourceInfo\x12\x14\n\x0c\x65xpr_version\x18\x06 \x01(\t\x12\x1c\n\x04\x65xpr\x18\x04 \x01(\x0b\x32\x0e.cel.expr.Expr\x1aH\n\x11ReferenceMapEntry\x12\x0b\n\x03key\x18\x01 \x01(\x03\x12\"\n\x05value\x18\x02 \x01(\x0b\x32\x13.cel.expr.Reference:\x02\x38\x01\x1a>\n\x0cTypeMapEntry\x12\x0b\n\x03key\x18\x01 \x01(\x03\x12\x1d\n\x05value\x18\x02 \x01(\x0b\x32\x0e.cel.expr.Type:\x02\x38\x01\"\xa2\x08\n\x04Type\x12%\n\x03\x64yn\x18\x01 \x01(\x0b\x32\x16.google.protobuf.EmptyH\x00\x12*\n\x04null\x18\x02 \x01(\x0e\x32\x1a.google.protobuf.NullValueH\x00\x12\x31\n\tprimitive\x18\x03 \x01(\x0e\x32\x1c.cel.expr.Type.PrimitiveTypeH\x00\x12/\n\x07wrapper\x18\x04 \x01(\x0e\x32\x1c.cel.expr.Type.PrimitiveTypeH\x00\x12\x32\n\nwell_known\x18\x05 \x01(\x0e\x32\x1c.cel.expr.Type.WellKnownTypeH\x00\x12,\n\tlist_type\x18\x06 \x01(\x0b\x32\x17.cel.expr.Type.ListTypeH\x00\x12*\n\x08map_type\x18\x07 \x01(\x0b\x32\x16.cel.expr.Type.MapTypeH\x00\x12/\n\x08\x66unction\x18\x08 \x01(\x0b\x32\x1b.cel.expr.Type.FunctionTypeH\x00\x12\x16\n\x0cmessage_type\x18\t \x01(\tH\x00\x12\x14\n\ntype_param\x18\n \x01(\tH\x00\x12\x1e\n\x04type\x18\x0b \x01(\x0b\x32\x0e.cel.expr.TypeH\x00\x12\'\n\x05\x65rror\x18\x0c \x01(\x0b\x32\x16.google.protobuf.EmptyH\x00\x12\x34\n\rabstract_type\x18\x0e \x01(\x0b\x32\x1b.cel.expr.Type.AbstractTypeH\x00\x1a-\n\x08ListType\x12!\n\telem_type\x18\x01 \x01(\x0b\x32\x0e.cel.expr.Type\x1aO\n\x07MapType\x12 \n\x08key_type\x18\x01 \x01(\x0b\x32\x0e.cel.expr.Type\x12\"\n\nvalue_type\x18\x02 \x01(\x0b\x32\x0e.cel.expr.Type\x1aV\n\x0c\x46unctionType\x12#\n\x0bresult_type\x18\x01 \x01(\x0b\x32\x0e.cel.expr.Type\x12!\n\targ_types\x18\x02 \x03(\x0b\x32\x0e.cel.expr.Type\x1a\x45\n\x0c\x41\x62stractType\x12\x0c\n\x04name\x18\x01 \x01(\t\x12\'\n\x0fparameter_types\x18\x02 \x03(\x0b\x32\x0e.cel.expr.Type\"s\n\rPrimitiveType\x12\x1e\n\x1aPRIMITIVE_TYPE_UNSPECIFIED\x10\x00\x12\x08\n\x04\x42OOL\x10\x01\x12\t\n\x05INT64\x10\x02\x12\n\n\x06UINT64\x10\x03\x12\n\n\x06\x44OUBLE\x10\x04\x12\n\n\x06STRING\x10\x05\x12\t\n\x05\x42YTES\x10\x06\"V\n\rWellKnownType\x12\x1f\n\x1bWELL_KNOWN_TYPE_UNSPECIFIED\x10\x00\x12\x07\n\x03\x41NY\x10\x01\x12\r\n\tTIMESTAMP\x10\x02\x12\x0c\n\x08\x44URATION\x10\x03\x42\x0b\n\ttype_kind\"\xc9\x03\n\x04\x44\x65\x63l\x12\x0c\n\x04name\x18\x01 \x01(\t\x12)\n\x05ident\x18\x02 \x01(\x0b\x32\x18.cel.expr.Decl.IdentDeclH\x00\x12/\n\x08\x66unction\x18\x03 \x01(\x0b\x32\x1b.cel.expr.Decl.FunctionDeclH\x00\x1aY\n\tIdentDecl\x12\x1c\n\x04type\x18\x01 \x01(\x0b\x32\x0e.cel.expr.Type\x12!\n\x05value\x18\x02 \x01(\x0b\x32\x12.cel.expr.Constant\x12\x0b\n\x03\x64oc\x18\x03 \x01(\t\x1a\xee\x01\n\x0c\x46unctionDecl\x12\x37\n\toverloads\x18\x01 \x03(\x0b\x32$.cel.expr.Decl.FunctionDecl.Overload\x1a\xa4\x01\n\x08Overload\x12\x13\n\x0boverload_id\x18\x01 \x01(\t\x12\x1e\n\x06params\x18\x02 \x03(\x0b\x32\x0e.cel.expr.Type\x12\x13\n\x0btype_params\x18\x03 \x03(\t\x12#\n\x0bresult_type\x18\x04 \x01(\x0b\x32\x0e.cel.expr.Type\x12\x1c\n\x14is_instance_function\x18\x05 \x01(\x08\x12\x0b\n\x03\x64oc\x18\x06 \x01(\tB\x0b\n\tdecl_kind\"Q\n\tReference\x12\x0c\n\x04name\x18\x01 \x01(\t\x12\x13\n\x0boverload_id\x18\x03 \x03(\t\x12!\n\x05value\x18\x04 \x01(\x0b\x32\x12.cel.expr.ConstantB,\n\x0c\x64\x65v.cel.exprB\tDeclProtoP\x01Z\x0c\x63\x65l.dev/expr\xf8\x01\x01\x62\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module Cel
  module Expr
    CheckedExpr = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.CheckedExpr").msgclass
    Type = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type").msgclass
    Type::ListType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type.ListType").msgclass
    Type::MapType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type.MapType").msgclass
    Type::FunctionType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type.FunctionType").msgclass
    Type::AbstractType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type.AbstractType").msgclass
    Type::PrimitiveType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type.PrimitiveType").enummodule
    Type::WellKnownType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Type.WellKnownType").enummodule
    Decl = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Decl").msgclass
    Decl::IdentDecl = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Decl.IdentDecl").msgclass
    Decl::FunctionDecl = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Decl.FunctionDecl").msgclass
    Decl::FunctionDecl::Overload = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Decl.FunctionDecl.Overload").msgclass
    Reference = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("cel.expr.Reference").msgclass
  end
end
