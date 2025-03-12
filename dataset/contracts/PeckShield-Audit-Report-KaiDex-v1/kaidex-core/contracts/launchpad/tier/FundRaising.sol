//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../../libraries/TransferHelper.sol";
import "../../interfaces/ITierSystem.sol";

contract FundRaising is ReentrancyGuard, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        bool claimed; // default false
    }
    // The buy token
    ERC20 public buyToken; // Ex.USDT, DAI ... If buyToken = address(0) => so this is using KAI native
    // The offering token
    ERC20 public offeringToken;
    // The timestamp when raising starts
    uint256 public startTime;
    // The timestamp when raising ends
    uint256 public endTime;
    // The timestamp user staring harvest
    uint256 public harvestTime;
    // total amount of raising tokens need to be raised
    uint256 public raisingAmount;
    // total amount of offeringToken that will offer
    uint256 public offeringAmount;
    // total amount of raising tokens that have already raised
    uint256 public totalAmount;
    // address => amount
    mapping(address => UserInfo) public userInfo;
    // participators
    address[] public addressList;

    // Tier system
    ITierSystem public tierSystem;

    // snapshot ids
    uint256 public snapshotFrom;
    uint256 public snapshotTo;

    // Project multiplier: 10000 ~ 1, 1000 ~ 0.1
    uint256 public multiplier;

    event Deposit(address indexed user, uint256 amount);
    event Harvest(
        address indexed user,
        uint256 offeringAmount,
        uint256 excessAmount
    );

    struct TokenInfo {
        ERC20 token;
        uint256 decimals;
        string name;
        string symbol;
    }

    constructor(
        ERC20 _buyToken,
        ERC20 _offeringToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _harvestTime,
        uint256 _offeringAmount,
        uint256 _raisingAmount,
        ITierSystem _tierSystem,
        uint256 _snapshotFrom,
        uint256 _snapshotTo,
        uint256 _multiplier
    ) public {
        require(
            _harvestTime >= _endTime &&
            _endTime > _startTime &&
            _startTime > block.timestamp
        );
        buyToken = _buyToken;
        offeringToken = _offeringToken;
        startTime = _startTime;
        endTime = _endTime;
        harvestTime = _harvestTime;
        offeringAmount = _offeringAmount;
        raisingAmount = _raisingAmount;
        totalAmount = 0;
        tierSystem = _tierSystem;
        snapshotFrom = _snapshotFrom;
        snapshotTo = _snapshotTo;
        multiplier = _multiplier;
    }

    modifier depositAllowed(uint256 _amount) {
        require(
            block.timestamp > startTime && block.timestamp < endTime,
            "not raising time"
        );
        require(_amount > 0, "need _amount > 0");
        _;
    }

    modifier harvestAllowed() {
        require(block.timestamp > harvestTime, "not harvest time");
        require(userInfo[msg.sender].amount > 0, "have you participated?");
        require(!userInfo[msg.sender].claimed, "nothing to harvest");
        _;
    }

    function setSnapshotFrom (uint256 id) public onlyOwner {
        require(id > 0, 'Id invalid');
        snapshotFrom = id;
    }

    function setSnapshotTo (uint256 id) public onlyOwner {
        require(id > 0, 'Id invalid');
        snapshotTo = id;
    }


    function updateHarvestTime(uint256 _newTime) public onlyOwner {
        require(
            _newTime > block.timestamp && _newTime > endTime,
            "time invalid!!"
        );
        harvestTime = _newTime;
    }

    function updateEndTime(uint256 _newTime) public onlyOwner {
        require(
            _newTime > block.timestamp && _newTime < harvestTime,
            "time invalid!!"
        );
        endTime = _newTime;
    }

    function getInfo()
        public
        view
        returns (
            TokenInfo memory,
            TokenInfo memory,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        TokenInfo memory _buyToken;
        if (buyToken == ERC20(address(0))) {
            _buyToken = TokenInfo({
                token: ERC20(address(0)),
                decimals: 18,
                name: 'KardiaChain',
                symbol: 'KAI'
            });
        } else {
            _buyToken = getERC20Info(buyToken);
        }
        TokenInfo memory _offeringToken = getERC20Info(offeringToken);
        return (
            _buyToken,
            _offeringToken,
            startTime,
            endTime,
            harvestTime,
            offeringAmount,
            raisingAmount
        );
    }

    function getERC20Info(ERC20 _token)
        private
        view
        returns (TokenInfo memory)
    {
        return
            TokenInfo({
                token: _token,
                decimals: _token.decimals(),
                name: _token.name(),
                symbol: _token.symbol()
            });
    }

    function setOfferingAmount(uint256 _offerAmount) public onlyOwner {
        require(block.timestamp < startTime, "no");
        offeringAmount = _offerAmount;
    }

    function setRaisingAmount(uint256 _raisingAmount) public onlyOwner {
        require(block.timestamp < startTime, "no");
        raisingAmount = _raisingAmount;
    }

    function deposit(uint256 _amount)
        public
        payable
        nonReentrant
        depositAllowed(_amount)
        whenNotPaused
    {
        uint256 maxAllocation = _computeMaxAllocation(msg.sender);
        require(
            maxAllocation > userInfo[msg.sender].amount,
            "not eligible amount!!"
        );
        uint256 eligibleAmount = maxAllocation - userInfo[msg.sender].amount;
        uint256 amount = _amount;
        if (eligibleAmount < _amount) {
            amount = eligibleAmount;
        }
        if (buyToken == IERC20(address(0))) {
            require(msg.value >= amount, "amount not enough");
            if (msg.value > amount) {
                TransferHelper.safeTransferKAI(msg.sender, msg.value - amount);
            }
        } else {
            buyToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                amount
            );
        }
        if (userInfo[msg.sender].amount == 0) {
            addressList.push(address(msg.sender));
        }
        userInfo[msg.sender].amount = userInfo[msg.sender].amount.add(amount);
        totalAmount = totalAmount.add(amount);
        emit Deposit(msg.sender, amount);
    }

    function _computeMaxAllocation(address _account)
        private
        view
        returns (uint256)
    {
        require(snapshotFrom > 0 && snapshotTo > snapshotFrom, "Snapshot id not set");
        uint256 tier = tierSystem.getTierFromTo(_account, snapshotFrom, snapshotTo);
        if (tier == 0) return 0;
        return allocations(tier);
    }

    function getTier (address _account) external view returns (uint256) {
        return tierSystem.getTierFromTo(_account, snapshotFrom, snapshotTo);
    }

    function getAllocation (address _account) external view returns (uint256) {
        uint256 tier = tierSystem.getTierFromTo(_account, snapshotFrom, snapshotTo);
        if (tier == 0) return 0;
        return allocations(tier);
    }

    function getAllocationPoint (address _account) external view returns (uint256) {
        uint256 tier = tierSystem.getTierFromTo(_account, snapshotFrom, snapshotTo);
        if (tier == 0) return 0;
        return tierSystem.getAllocationPoint(tier);
    }

    function allocations(uint256 _tier) view public returns (uint256) {
        uint256 _alloPoint = tierSystem.getAllocationPoint(_tier);
        if (buyToken == IERC20(address(0)) ) {
            return _alloPoint.mul(multiplier).mul(1e18).div(10000);
        }
        return _alloPoint.mul(multiplier).mul(10 ** buyToken.decimals()).div(10000);
    }

    function harvest() public nonReentrant harvestAllowed whenNotPaused {
        uint256 offeringTokenAmount = getOfferingAmount(msg.sender);
        uint256 refundingTokenAmount = getRefundingAmount(msg.sender);
        offeringToken.safeTransfer(address(msg.sender), offeringTokenAmount);
        if (refundingTokenAmount > 0) {
            if (buyToken == IERC20(address(0))) {
                TransferHelper.safeTransferKAI(
                    msg.sender,
                    refundingTokenAmount
                );
            } else {
                buyToken.safeTransfer(
                    address(msg.sender),
                    refundingTokenAmount
                );
            }
        }
        userInfo[msg.sender].claimed = true;
        emit Harvest(msg.sender, offeringTokenAmount, refundingTokenAmount);
    }

    function hasHarvest(address _user) external view returns (bool) {
        return userInfo[_user].claimed;
    }

    function getUserAllocation(address _user) public view returns (uint256) {
        return userInfo[_user].amount.mul(1e18).div(totalAmount);
    }

    // get the amount of Offering token you will get
    function getOfferingAmount(address _user) public view returns (uint256) {
        if (totalAmount > raisingAmount) {
            uint256 allocation = getUserAllocation(_user);
            return offeringAmount.mul(allocation).div(1e18);
        } else {
            // userInfo[_user] / (raisingAmount / offeringAmount)
            return
                userInfo[_user].amount.mul(offeringAmount).div(raisingAmount);
        }
    }

    // get the amount of lp token you will be refunded
    function getRefundingAmount(address _user) public view returns (uint256) {
        if (totalAmount <= raisingAmount) {
            return 0;
        }
        uint256 allocation = getUserAllocation(_user);
        uint256 payAmount = raisingAmount.mul(allocation).div(1e18);
        return userInfo[_user].amount.sub(payAmount);
    }

    function getAddressListLength() external view returns (uint256) {
        return addressList.length;
    }

    function finalWithdraw(address _destination) public onlyOwner {
        if (buyToken == IERC20(address(0))) {
            TransferHelper.safeTransferKAI(_destination, address(this).balance);
        } else {
            buyToken.safeTransfer(
                address(_destination),
                buyToken.balanceOf(address(this))
            );
        }
    }

    function emergencyWithdraw(address token, address payable to)
        public
        onlyOwner
    {
        if (token == address(0)) {
            to.transfer(address(this).balance);
        } else {
            ERC20(token).safeTransfer(
                to,
                ERC20(token).balanceOf(address(this))
            );
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
