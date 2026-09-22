enum NavigationDirection {
  forward,
  back,
  left,
  right,
  backLeft,
  backRight,
  forwardLeft,
  forwardRight,
}

extension NavigationDirectionCommand on NavigationDirection {
  String get command {
    switch (this) {
      case NavigationDirection.forward:
        return 'F';

      case NavigationDirection.back:
        return 'B';

      case NavigationDirection.left:
        return 'L';

      case NavigationDirection.right:
        return 'R';

      case NavigationDirection.backLeft:
        return 'BL';

      case NavigationDirection.backRight:
        return 'BR';

      case NavigationDirection.forwardLeft:
        return 'FL';

      case NavigationDirection.forwardRight:
        return 'FR';
    }
  }
}