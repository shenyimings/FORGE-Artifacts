// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OwnableUpgradeable as Ownable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import {IERC721Upgradeable as IERC721} from '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';
import {ERC20Upgradeable as ERC20} from '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {IERC20Upgradeable as IERC20} from '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import "./interfaces/IMasterMantis.sol";
import "./interfaces/IveMNT.sol";

contract veMNT is Initializable, ERC20, Ownable, ReentrancyGuard, IveMNT {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    event MasterMantisAdded(address indexed masterMantis);
    event MasterMantisRemoved(address indexed masterMantis);
    event MarketplaceSet(address indexed marketplace);
    event WhitelistSet(address indexed whitelist, bool status);

    uint256 public veMntPerSec;
    uint256 public decayFactor;
    IERC20 public mntLp;
    address[] public masterMantisList;

    struct UserData {
        uint256 amount;
        uint256 veMntRate;
        uint256 lastClaim;
    }

    mapping(address => UserData) public userData;

    mapping(address => bool) public override whitelisted;

    address public marketplace;


    modifier checkCaller() {
        require(msg.sender == tx.origin || whitelisted[msg.sender], 'Caller not allowed');
        _;
    }

    modifier onlyMarketplace() {
        require(msg.sender == marketplace, 'Not marketplace');
        _;
    }

    function initialize(address _mntLp) public initializer {
        require(address(_mntLp) != address(0), 'zero address');
        __ERC20_init('vote MNT', 'veMNT');
        __Ownable_init();
        __ReentrancyGuard_init_unchained();

        veMntPerSec = 3170979198376;
        decayFactor = veMntPerSec / (2 * 365 days);     // veMnt rate goes to 0 after 2 years.
        mntLp = IERC20(_mntLp);
    }

    function addMasterMantis(address _masterMantis) external onlyOwner {
        require(_masterMantis != address(0), "Cannot be zero address");
        masterMantisList.push(_masterMantis);
        emit MasterMantisAdded(_masterMantis);
    }

    function removeMasterMantis(uint256 index, address _masterMantis) external onlyOwner {
        require(masterMantisList[index] == _masterMantis, "Wrong index");
        masterMantisList[index] = masterMantisList[masterMantisList.length-1];
        masterMantisList.pop();
        emit MasterMantisRemoved(_masterMantis);
    }

    function setMarketplace(address _marketplace) external onlyOwner {
        require(_marketplace != address(0), "Cannot be zero address");
        marketplace = _marketplace;
        emit MarketplaceSet(_marketplace);
    }

    function setWhitelist(address _whitelist, bool _status) external onlyOwner {
        require(_whitelist != address(0), "Cannot be zero address");
        whitelisted[_whitelist] = _status;
        emit WhitelistSet(_whitelist, _status);
    }

    function _getNewRate(
        UserData memory user,
        uint256 amount,
        uint256 amountRate
    ) internal view returns (uint256 newRate, uint256 newLastClaim) {
        uint256 currentAmount = user.amount;
        uint256 newAmount = currentAmount + amount;
        newRate = ((currentAmount * user.veMntRate) + (amount * amountRate)) / newAmount;
        if (newAmount > 0 && newRate > 0) {
            newLastClaim = block.timestamp - ((currentAmount * user.veMntRate * (block.timestamp - user.lastClaim)) / (newAmount * newRate));
        } else {
            newLastClaim = block.timestamp;
        }
    }

    function deposit(uint256 amount) external checkCaller nonReentrant {
        require(amount > 0, "Cannot be 0");
        mntLp.safeTransferFrom(msg.sender, address(this), amount);
        UserData memory user = userData[msg.sender];
        if (user.amount == 0) {
            user.veMntRate = veMntPerSec;
            user.lastClaim = block.timestamp;
            user.amount = amount;
        } else {
            (uint256 newRate, uint256 newLastClaim) = _getNewRate(user, amount, veMntPerSec);
            user.veMntRate = newRate;
            user.lastClaim = newLastClaim;
            user.amount += amount;
        }
        userData[msg.sender] = user;
        emit Deposit(msg.sender, amount);
    }

    function claim() external nonReentrant {
        _claim(msg.sender);
    }

    function _claim(address recipient) internal {
        uint256 claimAmount = claimable(recipient);
        if (claimAmount > 0) {
            UserData storage user = userData[recipient];
            uint256 decay = getDecay(user.lastClaim);
            if (user.veMntRate > decay) {
                unchecked {
                    user.veMntRate -= decay;
                }
            } else {
                user.veMntRate = 0;
            }
            user.lastClaim = block.timestamp;
            _mint(recipient, claimAmount);
            emit Claim(recipient, claimAmount);
        }
    }

    function claimable(address _userAddress) public view returns (uint256) {
        UserData memory user = userData[_userAddress];
        return user.amount * user.veMntRate * (block.timestamp - user.lastClaim) / 1e18;
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot be 0");
        UserData memory user = userData[msg.sender];
        require(user.amount >= amount, "Cannot withdraw more than deposited");
        uint256 veMntBalance = balanceOf(msg.sender);
        _burn(msg.sender, veMntBalance);
        _triggerVoteReset(msg.sender);
        userData[msg.sender] = UserData({
            amount: user.amount - amount,
            veMntRate: veMntPerSec,
            lastClaim: block.timestamp
        });
        mntLp.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function getDecay(uint256 lastClaim) internal view returns (uint256) {
        return decayFactor * (block.timestamp - lastClaim);
    }

    function takeVeMnt(
        address from,
        uint256 percent
    ) external override onlyMarketplace returns (uint256 mntLpAmount, uint256 veMntAmount, uint256 veMntRate) {
        UserData memory user = userData[from];
        mntLpAmount = user.amount * percent / 1e4;
        veMntAmount = balanceOf(from) * percent / 1e4;
        veMntRate = user.veMntRate;
        userData[from].amount -= mntLpAmount;
        mntLp.safeTransfer(marketplace, mntLpAmount);
        _transfer(from, marketplace, veMntAmount);
    }

    function releaseVeMnt(
        address from,
        uint256 mntLpAmount,
        uint256 veMntAmount,
        uint256 veMntRate
    ) external override onlyMarketplace returns (bool) {
        UserData memory user = userData[from];
        mntLp.safeTransferFrom(marketplace, address(this), mntLpAmount);
        _transfer(marketplace, from, veMntAmount);
        (user.veMntRate, user.lastClaim) = _getNewRate(user, mntLpAmount, veMntRate);
        user.amount += mntLpAmount;
        userData[from] = user;
        return true;
    }

    function exchangeVeMnt(
        address from,
        address to,
        uint256 mntLpAmount,
        uint256 veMntAmount,
        uint256 veMntRate
    ) external override onlyMarketplace returns (bool) {
        _claim(to);
        UserData memory userTo = userData[to];
        mntLp.safeTransferFrom(marketplace, address(this), mntLpAmount);
        _transfer(marketplace, to, veMntAmount);
        (userTo.veMntRate, userTo.lastClaim) = _getNewRate(userTo, mntLpAmount, veMntRate);
        userTo.amount += mntLpAmount;
        userData[to] = userTo;
        _triggerVoteReset(from);
        return true;
    }

    function _triggerVoteReset(address user) internal {
        uint256 masterMantisListSize = masterMantisList.length;
        for (uint256 i = 0; i < masterMantisListSize; i++) {
            address masterMantis = masterMantisList[i];
            IMasterMantis(masterMantis).resetVote(user);
        }
    }

    function _updateMasterRewardFactor(address user) internal {
        uint256 masterMantisListSize = masterMantisList.length;
        for (uint256 i = 0; i < masterMantisListSize; i++) {
            address masterMantis = masterMantisList[i];
            IMasterMantis(masterMantis).updateRewardFactor(user);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal override {
        require(from == address(0) || to == address(0) || (!whitelisted[from] && to == marketplace) || (from == marketplace), "Transfer not allowed");
    }

    function _afterTokenTransfer(address from, address to, uint256) internal override {
        if (from == address(0)) {
            _updateMasterRewardFactor(to);
        } else if (to == address(0)) {
            _updateMasterRewardFactor(from);
        } else if (!whitelisted[from] && to == marketplace) {
            _updateMasterRewardFactor(from);
        } else if (from == marketplace) {
            _updateMasterRewardFactor(to);
        }
    }
}