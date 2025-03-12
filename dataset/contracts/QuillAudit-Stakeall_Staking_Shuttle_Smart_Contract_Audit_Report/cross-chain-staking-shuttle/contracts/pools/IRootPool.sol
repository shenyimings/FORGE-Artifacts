pragma solidity 0.8.7;

contract IRootPool {


    event ShuttleProcessingInitiated(
        uint256 _shuttleNumber
    );
    event ShuttleProcessed(
        uint256 _shuttleNumber,
        uint256 _stakeAmount,
        uint256 _stMaticAmount,
        ShuttleProcessingStatus _processingStatus
    );
}

enum ShuttleProcessingStatus {
    PROCESSED,
    CANCELLED
}


interface IFxStateRootTunnel {
    function receiveMessage(bytes memory message) external;

    function sendMessageToChild(bytes memory message) external;

    function readData() external returns (uint256, uint256);
}

interface IWithdrawManagerProxy {
    function processExits(address token) external;
}

interface IERC20PredicateBurnOnly {
    function startExitWithBurntTokens(bytes calldata data) external;
}

interface IDepositManagerProxy {
    function depositERC20ForUser(
        address token,
        address user,
        uint256 amount
    ) external;
}

interface IPolidoAdapter {
    function depositForAndBridge(address _beneficiary, uint256 _amount)
        external
        returns (uint256);
}
