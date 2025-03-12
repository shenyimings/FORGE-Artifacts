pragma solidity 0.4.25;


import "./FeeSharingInterface.sol";
import "./Withdrawable.sol";
import "./Utils2.sol";
import "./NetworkInterface.sol";

/**
 * @title Helps contracts guard against reentrancy attacks.
 */
contract ReentrancyGuard {

    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private guardCounter = 1;

    /**
     * @dev Prevents a function from calling itself, directly or indirectly.
     * Calling one `nonReentrant` function from
     * another is not supported. Instead, you can implement a
     * `private` function doing the actual work, and an `external`
     * wrapper marked as `nonReentrant`.
     */
    modifier nonReentrant() {
        guardCounter += 1;
        uint256 localCounter = guardCounter;
        _;
        require(localCounter == guardCounter);
    }
}

contract FeeSharing is Withdrawable, FeeSharingInterface, Utils2, ReentrancyGuard {

    mapping(address=>uint) public walletFeesInBps; // commission (percentage) of a wallet
    mapping(address=>uint) public walletFeesToPay; // amount of fee to pay for a wallet
    mapping(address=>uint) public feePayedPerWallet; // total fee payed to a wallet

    NetworkInterface public network;

    constructor(address _admin, NetworkInterface _network) public {
      require(_admin != address(0));
      require(_network != address(0));
      network = _network;
      admin = _admin;
    }

    event SetNewNetworkContract(NetworkInterface _network);
    function setNetworkContract(NetworkInterface _network) public onlyAdmin {
      require(_network != address(0));
      network = _network;
      emit SetNewNetworkContract(_network);
    }

    event WalletFeesSet(address wallet, uint feesInBps);
    function setWalletFees(address wallet, uint feesInBps) public onlyAdmin {
        require(feesInBps < 10000); // under 100%
        walletFeesInBps[wallet] = feesInBps;
        emit WalletFeesSet(wallet, feesInBps);
    }

    event AssignFeeToWallet(address wallet, uint walletFee);
    function handleFees(address wallet)
      public
      nonReentrant
      payable
      returns(bool)
    {
        require(msg.sender == address(network));
        require(msg.value <= MAX_QTY);
        uint fee = msg.value;

        uint walletFee = fee * walletFeesInBps[wallet] / 10000;
        require(fee >= walletFee);

        if (walletFee > 0) {
            walletFeesToPay[wallet] += walletFee;
            emit AssignFeeToWallet(wallet, walletFee);
        }
        return true;
    }

    event SendWalletFees(address indexed wallet, address sender);
    // this function is callable by anyone
    function sendFeeToWallet(address wallet) public nonReentrant {
        uint feeAmount = walletFeesToPay[wallet];
        require(feeAmount > 0);

        uint thisBalance = address(this).balance;
        uint walletBalance = wallet.balance;

        require(thisBalance >= feeAmount);

        walletFeesToPay[wallet] = 0;
        wallet.transfer(feeAmount);
        feePayedPerWallet[wallet] += feeAmount;

        uint newThisBalance = address(this).balance;
        require(newThisBalance == thisBalance - feeAmount);

        uint newWalletBalance = wallet.balance;
        require(newWalletBalance == walletBalance + feeAmount);

        emit SendWalletFees(wallet, msg.sender);
    }
}
