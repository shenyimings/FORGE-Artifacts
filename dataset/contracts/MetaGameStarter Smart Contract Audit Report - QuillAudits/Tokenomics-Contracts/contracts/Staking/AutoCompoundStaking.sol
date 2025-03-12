pragma solidity ^0.8.0.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract Staking is AccessControlEnumerableUpgradeable {
    using SafeERC20 for IERC20; 
    
    uint256 constant PRECISION = 1 ether;
    uint256 constant BASIS_POINTS = 1e9;

    bytes32 public constant SUPPLIER_ROLE = keccak256("SUPPLIER");
    
    uint256 totalShares;
    uint128 totalAmountStaked;
    uint128 rewardRate = 0;
    uint128 rewardEnd;
    uint128 lastUpdate;

    IERC20 token;
    bool paused;

    mapping(address => uint256) public shares;
    mapping(address => bool) private _validTokenSupplier;

    constructor(IERC20 _token) {
        token = _token;
        totalAmountStaked = 1;
        totalShares = 1;
        lastUpdate = uint128(block.timestamp);
        shares[address(0)] = 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function stake(uint256 tokenAmount) public {
        uint256 sharesToMint = tokenToShares(tokenAmount);

        require(tokenAmount > PRECISION, "at least 1 token");
        require(sharesToMint != 0, "ZERO MINT");

        _processPayment(msg.sender, address(this), tokenAmount);

        shares[msg.sender] += sharesToMint;

        totalAmountStaked += uint128(tokenAmount);
        totalShares += uint128(sharesToMint);

        // just for testing: 
        require(sharesToToken(sharesToMint) == tokenAmount, "deposit loss or win");
    }

    function unstake(uint256 sharesAmount) public {
        uint256 tokenToRelease = sharesToToken(sharesAmount);

        require(tokenToRelease != 0, "ZERO WITHDRAW");

        shares[msg.sender] -= sharesAmount;

        totalAmountStaked -= uint128(tokenToRelease);
        totalShares -= uint128(sharesAmount);

        _processPayment(address(this), msg.sender, tokenToRelease);

        // just for testing:
        require(sharesToToken(sharesAmount) == tokenToRelease, "deposit loss or win");
    }

    function notifyShareholder(address _token, uint256 _amount) external returns(bool) {
        require(_validTokenSupplier[msg.sender], "auth");
        require(_token == address(token));
        _updateRewardRate();
    }

    function _allowedToStake(address who, uint256 amount) internal view returns(bool) {
        return !paused && amount >= PRECISION;
    }

    function sharesToToken(uint256 amount) internal view returns(uint256) {
        return amount * _totalAmountStaked() / _totalShares();
    }

    function tokenToShares(uint256 amount) internal view returns(uint256) {
        return amount * _totalShares() / _totalAmountStaked();
    }

    // cannot evaluate to 0, see constructor
    function _totalAmountStaked() public view returns(uint256) {
        uint256 _rewardEnd = rewardEnd;
        if(_rewardEnd < block.timestamp) {
            if(_rewardEnd <= lastUpdate) return totalAmountStaked;
            return totalAmountStaked + (_rewardEnd - lastUpdate) * rewardRate;
        }
        return totalAmountStaked + (block.timestamp - lastUpdate) * rewardRate; 
    }

    function _totalReserves() internal view returns(uint256) {
        return token.balanceOf(address(this)) - _totalAmountStaked();
    }

    function _totalShares() internal view returns(uint256) {
        return totalShares;
    }

/*     function _reservesSufficient() internal view returns(bool) {
        return _totalAmountStaked() <= totalReserves;
    } */

    function _updateRewardRate() internal {
        rewardRate = uint128(_totalReserves() / 7 days);
        rewardEnd = uint128(block.timestamp + 7 days);
        
        // emit NewRewardRate()
    }

    function _updateTime() internal {
        lastUpdate = uint128(block.timestamp);
    }

    function _processPayment(address from, address to, uint256 amount) internal {
        token.safeTransferFrom(from, to, amount);
    }

    function time() public view returns(uint256) {
        return block.timestamp;
    }

    function balanceOf(address who) external view returns(uint256) {
        return sharesToToken(shares[who]);
    }

    function sharePrice() external view returns(uint256) {
        return BASIS_POINTS * _totalAmountStaked() / totalShares;
    }

    fallback() external payable {}
}