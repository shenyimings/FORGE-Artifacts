pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./interfaces/IidoMaster.sol";

contract IDOMaster is IidoMaster, Ownable{
    using SafeMath for uint256;
    using SafeERC20 for ERC20Burnable;
    using SafeERC20 for ERC20;

    ERC20Burnable public override feeToken;
    address payable public override feeWallet;
    address public creatorProxy;
    uint256 public override feeAmount;
    uint256 public override burnPercent;
    uint256 public override divider;

    uint256 public override feeFundsPercent = 0; /* Default Fee 0% */

    mapping(address => IDOInfo) public idoInfo;

    struct IDOInfo {
        uint256 tokenPrice;
        address payableToken;
        address payToken;
        address rewardToken;
        uint256 startTimestamp;
        uint256 finishTimestamp;
        uint256 startClaimTimestamp;
        uint256 minEthPayment;
        uint256 maxEthPayment;
        uint256 maxDistributedTokenAmount;
    }


    event IDOCreated(address idoPool, 
        uint256 tokenPrice, 
        address payableToken,
        address rewardToken,
        uint256 startTimestamp,
        uint256 finishTimestamp,
        uint256 startClaimTimestamp,
        uint256 minEthPayment,
        uint256 maxEthPayment,
        uint256 maxDistributedTokenAmount);

    event CreatorUpdated(address idoCreator);
    event TokenFeeUpdated(address newFeeToken);
    event FeeAmountUpdated(uint256 newFeeAmount);
    event BurnPercentUpdated(uint256 newBurnPercent, uint256 divider);
    event FeeWalletUpdated(address newFeeWallet);

    constructor(
        ERC20Burnable _feeToken,
        address payable _feeWallet,
        uint256 _feeAmount,
        uint256 _burnPercent
    ) public {
        feeToken = _feeToken;
        feeAmount = _feeAmount;
        feeWallet = _feeWallet;
        burnPercent = _burnPercent;
        divider = 100;
    }

    function setFeeToken(address _newFeeToken) external onlyOwner {
        require(isContract(_newFeeToken), "New address is not a token");
        feeToken = ERC20Burnable(_newFeeToken);

        emit TokenFeeUpdated(_newFeeToken);
    }

    function setFeeAmount(uint256 _newFeeAmount) external onlyOwner {
        feeAmount = _newFeeAmount;

        emit FeeAmountUpdated(_newFeeAmount);
    }

    function setFeeWallet(address payable _newFeeWallet) external onlyOwner {
        feeWallet = _newFeeWallet;

        emit FeeWalletUpdated(_newFeeWallet);
    }

    function setBurnPercent(uint256 _newBurnPercent, uint256 _newDivider)
        external
        onlyOwner
    {
        require(_newBurnPercent <= _newDivider, "Burn percent must be less than divider");
        burnPercent = _newBurnPercent;
        divider = _newDivider;

        emit BurnPercentUpdated(_newBurnPercent, _newDivider);
    }


    function setFeeFundsPercent(uint256 _feeFundsPercent)
        external
        onlyOwner
    {
        // require(_feeFundsPercent >= feePercentage, "Fee Percentage has to be >= 1");
        require(_feeFundsPercent <= 99, "Fee Percentage has to be < 100");
        feeFundsPercent = _feeFundsPercent;
    }

    function setCreatorProxy(address _creator) external onlyOwner {
        require(isContract(_creator), "Error address");
        creatorProxy = _creator;
        emit CreatorUpdated(creatorProxy);
    }

    function registrateIDO(
        address _poolAddress,
        uint256 _tokenPrice,
        address _payableToken,
        address _rewardToken,
        uint256 _startTimestamp,
        uint256 _finishTimestamp,
        uint256 _startClaimTimestamp,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _maxDistributedTokenAmount
    ) external override {

    require(msg.sender ==  creatorProxy, "registrateIDO: bad role");

    IDOInfo storage info = idoInfo[_poolAddress];
    info.tokenPrice = _tokenPrice;
    info.payableToken = _payableToken;
    info.rewardToken = _rewardToken;
    info.startTimestamp = _startTimestamp;
    info.finishTimestamp = _finishTimestamp;
    info.startClaimTimestamp = _startClaimTimestamp;
    info.minEthPayment = _minEthPayment;
    info.maxEthPayment = _maxEthPayment;
    info.maxDistributedTokenAmount = _maxDistributedTokenAmount;

    emit IDOCreated(_poolAddress,
            _tokenPrice,
            _payableToken,
            _rewardToken,
            _startTimestamp,
            _finishTimestamp,
            _startClaimTimestamp,
            _minEthPayment,
            _maxEthPayment,
            _maxDistributedTokenAmount);
    }

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    // ============ Version Control ============
    function version() external pure returns (uint256) {
        return 101; // 1.0.1
    }
}