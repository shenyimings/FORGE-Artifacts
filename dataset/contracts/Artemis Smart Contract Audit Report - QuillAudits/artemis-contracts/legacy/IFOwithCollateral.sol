pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

contract IFOwithCollateral is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user
    struct UserInfo {
        uint256 amount;   // How many tokens the user has provided.
        bool claimed;  // default false
        bool hasCollateral; // default false
    }

    // Admin address
    address public adminAddress;
    // Raising token
    IERC20 public lpToken;
    // Offering token
    IERC20 public offeringToken;
    // The block in which the IFO starts
    uint256 public startBlock;
    // The block in which the IFO ends
    uint256 public endBlock;
    // Total amount of tokens being raised
    uint256 public raisingAmount;
    // total amount of offeringToken that will offer
    uint256 public offeringAmount;
    // total amount of raising tokens that have already raised
    uint256 public totalAmount;
    // 0
    uint256 public totalAdminLpWithdrawn = 0;
    // 2 week delay
    uint delayForFullSweep = 604800; // 14 days;
    // Collateral token
    IERC20 public collateralToken;

    // Required collateral amount
    uint256 public requiredCollateralAmount;
    // address => amount
    mapping (address => UserInfo) public userInfo;
    // Participants
    address[] public addressList;


    event Deposit(address indexed user, uint256 amount);
    event DepositCollateral(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 offeringAmount, uint256 excessAmount);
    event RequiredCollateralChanged(
        address collateralToken,
        uint256 newRequiredCollateral,
        uint256 oldRequiredCollateral
    );

    constructor(
        IERC20 _lpToken,
        IERC20 _offeringToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _offeringAmount,
        uint256 _raisingAmount,
        address _adminAddress,
        IERC20 _collateralToken,
        uint256 _requiredCollateralAmount
    ) public {

        _lpToken.balanceOf(address(this)); // Validate token address
        _offeringToken.balanceOf(address(this)); // Validate token address
        _collateralToken.balanceOf(address(this)); // Validate token address
        require(_endBlock > _startBlock, 'start <= end');
        require(_startBlock > block.number, 'too soon');
        require(_adminAddress != address(0));

        lpToken = _lpToken;
        offeringToken = _offeringToken;
        startBlock = _startBlock;
        endBlock = _endBlock;
        offeringAmount = _offeringAmount;
        raisingAmount= _raisingAmount;
        totalAmount = 0;
        adminAddress = _adminAddress;
        collateralToken = _collateralToken;
        requiredCollateralAmount = _requiredCollateralAmount;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    function setOfferingAmount(uint256 _offerAmount) public onlyAdmin {
        require (block.number < startBlock, 'ifo already started!');
        offeringAmount = _offerAmount;
    }

    function setRaisingAmount(uint256 _raisingAmount) public onlyAdmin {
        require (block.number < startBlock, 'ifo already started!');
        raisingAmount= _raisingAmount;
    }

    function setStartBlock(uint256 _startBlock) public onlyAdmin {
        require (block.number < startBlock, 'ifo already started!');
        startBlock= _startBlock;
    }

    function setEndBlock(uint256 _endBlock) public onlyAdmin {
        require (block.number < startBlock, 'ifo already started!');
        endBlock= _endBlock;
    }

    function setLpToken(IERC20 _lpToken) public onlyAdmin {
        require (block.number < startBlock, 'ifo already started!');
        lpToken= _lpToken;
    }

    function setOfferingToken(IERC20 _offeringToken) public onlyAdmin {
        require (block.number < startBlock, 'ifo already started!');
        offeringToken= _offeringToken;
    }

    function depositCollateral() public {
        require (block.number > startBlock && block.number < endBlock, 'not ifo time');
        require (!userInfo[msg.sender].hasCollateral, 'user already staked collateral');

        uint256 collateral_amount = collateralToken.balanceOf(msg.sender);
        require(collateral_amount >= requiredCollateralAmount, "depositCollateral:insufficient collateral");

        // collateralTokens with transfer-tax are NOT supported.
        collateralToken.safeTransferFrom(msg.sender, address(this), requiredCollateralAmount);
        userInfo[msg.sender].hasCollateral = true;

        emit DepositCollateral(msg.sender, requiredCollateralAmount);
    }

    function deposit(uint256 _amount) public {
        require (block.number > startBlock && block.number < endBlock, 'not ifo time');
        require (_amount > 0, 'need _amount > 0');
        require (userInfo[msg.sender].hasCollateral, 'user needs to stake collateral first');

        if (userInfo[msg.sender].amount == 0) {
            addressList.push(msg.sender);
        }
        lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        userInfo[msg.sender].amount = userInfo[msg.sender].amount.add(_amount);
        totalAmount = totalAmount.add(_amount);
        emit Deposit(msg.sender, _amount);
    }

    function harvest() public nonReentrant {
        // Can only be called once for each user
        // Will refund Collateral, give IFO token, and return an overflow lpToken
        require (block.number > endBlock, 'not harvest time');
        require (!userInfo[msg.sender].claimed, 'already claimed');
        require (userInfo[msg.sender].hasCollateral, 'user needs to stake collateral first');
        uint256 offeringTokenAmount = getOfferingAmount(msg.sender);
        uint256 refundingTokenAmount = getRefundingAmount(msg.sender);

        userInfo[msg.sender].claimed = true;

        collateralToken.safeTransfer(msg.sender, requiredCollateralAmount);
        if (offeringTokenAmount > 0) {
            offeringToken.safeTransfer(msg.sender, offeringTokenAmount);
        }
        if (refundingTokenAmount > 0) {
            lpToken.safeTransfer(msg.sender, refundingTokenAmount);
        }
        emit Harvest(msg.sender, offeringTokenAmount, refundingTokenAmount);
    }

    function hasHarvested(address _user) external view returns(bool) {
        return userInfo[_user].claimed;
    }

    function hasCollateral(address _user) external view returns(bool) {
        return userInfo[_user].hasCollateral;
    }

    // allocation 100000 means 0.1(10%), 1 meanss 0.000001(0.0001%), 1000000 means 1(100%)
    function getUserAllocation(address _user) public view returns(uint256) {
        return userInfo[_user].amount.mul(1e6).div(totalAmount);
    }

    // get the amount of IFO token you will get
    function getOfferingAmount(address _user) public view returns(uint256) {
        if (userInfo[_user].amount <= 0) {
            return 0;
        }
        if (totalAmount > raisingAmount) {
            uint256 allocation = getUserAllocation(_user);
            return offeringAmount.mul(allocation).div(1e6);
        }
        else {
            // userInfo[_user] / (raisingAmount / offeringAmount)
            return userInfo[_user].amount.mul(offeringAmount).div(raisingAmount);
        }
    }

    // get the amount of lp token you will be refunded
    function getRefundingAmount(address _user) public view returns(uint256) {
        if (userInfo[_user].amount <= 0) {
            return 0;
        }
        if (totalAmount <= raisingAmount) {
            return 0;
        }
        uint256 allocation = getUserAllocation(_user);
        uint256 payAmount = raisingAmount.mul(allocation).div(1e6);
        return userInfo[_user].amount.sub(payAmount);
    }

    function getAddressListLength() external view returns(uint256) {
        return addressList.length;
    }

    function finalOfferingTokenWithdraw() public onlyAdmin {
        require (block.number > endBlock + delayForFullSweep, 'Must wait longer');
        offeringToken.safeTransfer(msg.sender, offeringToken.balanceOf(address(this)));
    }

    function finalWithdraw(uint256 _lpAmount) public onlyAdmin {
        if (block.number < endBlock + delayForFullSweep) {
            // Only check this condition for the first 14 days after IFO
            require (_lpAmount + totalAdminLpWithdrawn <= raisingAmount, 'withdraw exceeds raisingAmount');
        }
        require (_lpAmount <= lpToken.balanceOf(address(this)), 'not enough token 0');
        totalAdminLpWithdrawn = totalAdminLpWithdrawn + _lpAmount;
        lpToken.safeTransfer(msg.sender, _lpAmount);
    }

    function changeRequiredCollateralAmount(uint256 _newCollateralAmount) public onlyAdmin returns (bool) {
        require (block.number < startBlock, 'ifo already started!');
        uint256 oldCollateralAmount = requiredCollateralAmount;
        requiredCollateralAmount = _newCollateralAmount;
        emit RequiredCollateralChanged(
            address(collateralToken),
            requiredCollateralAmount,
            oldCollateralAmount
        );
    }

}
