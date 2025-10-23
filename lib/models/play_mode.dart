enum PlayMode {
  sequence('顺序播放', 'Icons.repeat'),
  single('单曲循环', 'Icons.repeat_one'),
  shuffle('随机播放', 'Icons.shuffle');

  final String label;
  final String iconName;

  const PlayMode(this.label, this.iconName);

  PlayMode get next {
    switch (this) {
      case PlayMode.sequence:
        return PlayMode.single;
      case PlayMode.single:
        return PlayMode.shuffle;
      case PlayMode.shuffle:
        return PlayMode.sequence;
    }
  }
}
