# frozen_string_literal: true

module Cel
  module Encoder
    module_function

    def encode(expr)
      case expr
      when Group
        ["group", encode(expr.value)]
      when Invoke
        enc = [
          "inv",
          (encode(expr.var) if expr.var),
          expr.func.to_s,
          *(if expr.args
              expr.func == :[] ? [encode(expr.args)] : expr.args.map(&method(:encode))
            end),
        ]
        enc.compact!
        enc
      when Operation
        [
          "op",
          expr.op.to_s,
          *expr.operands.map(&method(:encode)),
        ]
      when Condition
        [
          "cond",
          encode(expr.if),
          encode(expr.then),
          encode(expr.else),
        ]
      when Identifier
        [
          "id",
          expr.type.to_s,
          expr.id.to_s,
        ]
      when List
        ["lit",
         expr.type.to_s,
         *expr.value.map(&method(:encode))]
      when Map
        ["lit",
         expr.type.to_s,
         *expr.value.map { |kv| kv.map(&method(:encode)) }]
      when Number, Bool, String, Bytes
        ["lit", expr.type.to_s, expr.value]
      when Null
        %w[lit null]
      when Type
        ["lit", "type", expr.to_s]
      end
    end

    def decode(enc)
      case enc
      in ["group", stmt]
        Group.new(decode(stmt))
      in ["inv", var, ::String => func, *args]
        args = if func == "[]" && args.size == 1
          decode(args.first)
        elsif args.empty?
          nil
        else
          args.map(&method(:decode))
        end
        Invoke.new(func: func, var: decode(var), args: args)
      in ["inv", ::String => func, *args]
        args = nil if args.empty?
        Invoke.new(func: func, args: args.map(&method(:decode)))
      in ["op", ::String => op, *args]
        Operation.new(op, args.map(&method(:decode)))
      in ["cond", f, th, el]
        Condition.new(decode(f), decode(th), decode(el))
      in ["id", ::String => type, ::String => val]
        id = Identifier.new(val)
        id.type = TYPES[type.to_sym]
        id
      in ["lit", "list", *items]
        list = List.new(items.map(&method(:decode)))
        list
      in ["lit", "map", items]
        Map.new(items.map(&method(:decode)).each_slice(2))
      in ["lit", /\Aint|uint|double\z/ => type, Integer => val]
        Number.new(type.to_sym, val)
      in ["lit", "bool", val]
        Bool.new(val)
      in ["lit", "string", val]
        String.new(val)
      in ["lit", "bytes", val]
        Bytes.new(val)
      in ["lit", "null"]
        Null.new
      in ["lit", "type", type]
        TYPES[type.to_sym]
      end
    end
  end
end
