/// A request result never confirms that a dialog appeared or a review was left.
enum ReviewRequestStatus {
  requested,
  conditionsNotMet,
  alreadyPending,
  appNotActive,
  noActiveWindow,
  notAvailable,
  cancelled,
  failed,
}

class ReviewRequestResult {
  const ReviewRequestResult(this.status, {this.errorCode, this.message});

  final ReviewRequestStatus status;
  final String? errorCode;
  final String? message;

  @override
  String toString() =>
      'ReviewRequestResult(${status.name}'
      '${errorCode == null ? '' : ', $errorCode'}'
      '${message == null ? '' : ', $message'})';
}
