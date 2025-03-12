pragma solidity 0.8.7;

contract IChildPool {
    enum ShuttleStatus {
        UNAVAILABLE,
        AVAILABLE,
        ENROUTE,
        ARRIVED,
        EXPIRED,
        CANCELLED
    }

    struct Shuttle {
        uint256 totalAmount;
        ShuttleStatus status;
        uint256 recievedToken;
        uint256 expiry;
    }

    event ShuttleCreated(uint256 _shuttleNumber);
    event Deposit(uint256 _shuttlesNumber, address _sender, uint256 _amount);
    event ShuttleEnrouted(uint256 _shuttleNumber, uint256 _amount);
    event ShuttleArrived(
        uint256 _shuttleNumber,
        uint256 _amount,
        ShuttleStatus _status,
        uint256 _shuttleFee
    );
    event TokenClaimed(
        uint256 _shuttleNumber,
        address _token,
        address _beneficiary,
        uint256 _claimedAmount
    );

    event ShuttleExpired(uint256 _shuttleNumber);
    event ShuttleCancelled(uint256 _shuttleNumber);
    event FeeChanged(uint256 _fee);
    event ShuttleExpiryChanged(uint256 _shuttleExpiry);
}

enum ShuttleProcessingStatus {
    PROCESSED,
    CANCELLED
}

interface IFxStateChildTunnel {
    function sendMessageToRoot(bytes memory message) external;

    function readData()
        external
        returns (
            uint256,
            uint256,
            ShuttleProcessingStatus
        );
}

interface IMaticToken {
    function withdraw(uint256) external payable;
}

interface IFundCollector {
    function withdrawFunds(uint256 _amount) external;
}

