pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

     //\\___
    //  \\
   //    \\    
  //  /\  \\   
 //   \/   \\    
//          \\    

contract ArtemisIDO is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // A struct with info of each user, namely:
    //   How many tokens the user has provided
    //   If the user has claimed. Default: false
    //   If the user has collateral locked. Default: false
    struct UserInfo {
        uint256 amount;     
        bool claimed;       
        bool hasCollateral; 
    }
    
    // Gov Address
    address public adminAddress;  
    // Participants
    address[] public addressList;  
    // Token being raised
    IERC20 public raisingToken;
    // Token being sold    
    IERC20 public offeringToken; 
    // Collateral token    
    IERC20 public collateralToken;  
    // Start block of the IDO sale   
    uint256 public startBlock;
    // End block of the IDO sale (end block = start block + x amount of blocks)      
    uint256 public endBlock;
    // Harvest block      
    uint256 public claimBlock;
    // Amount of raisingToken being raised        
    uint256 public raisingAmount;   
    // Amount of offeringToken being sold
    uint256 public offeringAmount;  
    // Amount of raisingToken already raised
    uint256 public totalAmount;
    // Amount of raisingToken withdrawn by Gov    
    uint256 public totalAdminLpWithdrawn = 0;
    // Amount of collateralToken required to participate in the IDO    
    uint256 public requiredCollateralAmount;    
    // 14 days delay
    uint delayForFullSweep = 604800;
    // address => amount
    mapping (address => UserInfo) public userInfo;     

    event Deposit(address indexed user, uint256 amount); 
    event DepositCollateral(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 offeringAmount, uint256 excessAmount);
    event RequiredCollateralChanged(
        address collateralToken,
        uint256 newRequiredCollateral,
        uint256 oldRequiredCollateral
    );

    constructor(
        IERC20 _raisingToken,
        IERC20 _offeringToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _claimBlock,
        uint256 _offeringAmount,
        uint256 _raisingAmount,
        address _adminAddress,
        IERC20 _collateralToken,
        uint256 _requiredCollateralAmount
    ) public {

        _raisingToken.balanceOf(address(this));     // Validate token address
        _offeringToken.balanceOf(address(this));    // Validate token address
        _collateralToken.balanceOf(address(this));  // Validate token address
        require(_endBlock > _startBlock, 'start <= end');
        require(_claimBlock >= _endBlock, 'claim has to be >= end');
        require(_startBlock > block.number, 'too soon');
        require(_adminAddress != address(0));

        raisingToken = _raisingToken;
        offeringToken = _offeringToken;
        startBlock = _startBlock;
        endBlock = _endBlock;
        claimBlock = _claimBlock;
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
        require (block.number < startBlock, 'ido has already started');
        offeringAmount = _offerAmount;
    }

    function setRaisingAmount(uint256 _raisingAmount) public onlyAdmin {
        require (block.number < startBlock, 'ido has already started');
        raisingAmount= _raisingAmount;
    }

    function setStartBlock(uint256 _startBlock) public onlyAdmin {
        require (block.number < startBlock, 'ido has already started');
        startBlock= _startBlock;
    }

    function setEndBlock(uint256 _endBlock) public onlyAdmin {
        require (block.number < startBlock, 'ido has already started');
        endBlock= _endBlock;
    }

    function setClaimBlock(uint256 _claimBlock) public onlyAdmin {
        require(block.number < startBlock, 'ido has already started');
        claimBlock = _claimBlock;
    }

    function setRaisingToken(IERC20 _raisingToken) public onlyAdmin {
        require (block.number < startBlock, 'ido has already started');
        raisingToken= _raisingToken;
    }

    function setOfferingToken(IERC20 _offeringToken) public onlyAdmin {
        require (block.number < startBlock, 'ido has already started');
        offeringToken= _offeringToken;
    }

    function depositCollateral() public {
        require (block.number > startBlock && block.number < endBlock, 'ido has not started yet');
        require (!userInfo[msg.sender].hasCollateral, 'user has already staked collateral');

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
        raisingToken.safeTransferFrom(msg.sender, address(this), _amount);
        userInfo[msg.sender].amount = userInfo[msg.sender].amount.add(_amount);
        totalAmount = totalAmount.add(_amount);
        emit Deposit(msg.sender, _amount);
    }

    function harvest() public nonReentrant {
        // Can only be called once for each user
        // Will refund collateral, give tokens for sale, and return an overflow raisingToken
        require (block.number > endBlock + claimBlock, 'not harvest time');
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
            raisingToken.safeTransfer(msg.sender, refundingTokenAmount);
        }
        emit Harvest(msg.sender, offeringTokenAmount, refundingTokenAmount);
    }

    function hasHarvested(address _user) external view returns(bool) {
        return userInfo[_user].claimed;
    }

    function hasCollateral(address _user) external view returns(bool) {
        return userInfo[_user].hasCollateral;
    }

    // Allocation 100000 means 0.1(10%), 1 meanss 0.000001(0.0001%), 1000000 means 1(100%)
    function getUserAllocation(address _user) public view returns(uint256) {
        return userInfo[_user].amount.mul(1e6).div(totalAmount);
    }

    // Get the amount of IFO token a user will get
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
        require (_lpAmount <= raisingToken.balanceOf(address(this)), 'not enough token 0');
        totalAdminLpWithdrawn = totalAdminLpWithdrawn + _lpAmount;
        raisingToken.safeTransfer(msg.sender, _lpAmount);
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
