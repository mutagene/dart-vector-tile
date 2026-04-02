/// Representation for commands used to encode/decode geometry coordinates
class CommandID {
  static const int MoveTo = 1;
  static const int LineTo = 2;
  static const int ClosePath = 7;
}

/// Command and its utils
class Command {
  int id;
  int count;

  Command({required this.id, required this.count});

  factory Command.CommandInteger({required int command}) {
    return Command(id: decodeId(command), count: decodeCount(command));
  }

  static final bool _isRunningAsJs = identical(0, 0.0);

  static int decodeId(int command) {
    return command & 0x7;
  }

  static int decodeCount(int command) {
    return command >> 3;
  }

  static int zigZagEncode(int val) {
    return (val << 1) ^ (val >> 31);
  }

  static int zigZagDecode(int parameterInteger) {
    if (_isRunningAsJs) {
      final isNegative = (parameterInteger & 1) == 1;
      final base = parameterInteger ~/ 2;
      return isNegative ? -base - 1 : base;
    } else {
      return ((parameterInteger >> 1) ^ (-(parameterInteger & 1)));
    }
  }
}
