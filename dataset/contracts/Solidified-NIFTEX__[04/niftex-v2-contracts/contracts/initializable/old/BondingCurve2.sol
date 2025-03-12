// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../wallet/ShardedWallet.sol";
import "../../governance/IGovernance.sol";
import "../../interface/IERC1363Receiver.sol";
import "../../interface/IERC1363Spender.sol";

contract BondingCurve2 is IERC1363Spender {
    struct CurveCoordinates {
        uint256 x;
        uint256 k;
    }

    struct Asset {
        uint256 underlyingSupply;
        uint256 feeToNiftex;
        uint256 feeToArtist;
        uint256 totalSupply;
        mapping (address => uint256) balance;
    }

    // bytes32 public constant PCT_FEE_SUPPLIERS = bytes32(uint256(keccak256("PCT_FEE_SUPPLIERS")) - 1);
    bytes32 public constant PCT_FEE_SUPPLIERS  = 0xe4f5729eb40e38b5a39dfb36d76ead9f9bc286f06852595980c5078f1af7e8c9;
    // bytes32 public constant PCT_FEE_ARTIST    = bytes32(uint256(keccak256("PCT_FEE_ARTIST")) - 1);
    bytes32 public constant PCT_FEE_ARTIST     = 0xdd0618e2e2a17ff193a933618181c8f8909dc169e9707cce1921893a88739ca0;
    // bytes32 public constant PCT_FEE_NIFTEX    = bytes32(uint256(keccak256("PCT_FEE_NIFTEX")) - 1);
    bytes32 public constant PCT_FEE_NIFTEX     = 0xcfb1dd89e6f4506eca597e7558fbcfe22dbc7e0b9f2b3956e121d0e344d6f7aa;
    // bytes32 public constant LIQUIDITY_TIMELOCK   = bytes32(uint256(keccak256("LIQUIDITY_TIMELOCK")) - 1);
    bytes32 public constant LIQUIDITY_TIMELOCK = 0x4babff57ebd34f251a515a845400ed950a51f0a64c92e803a3e144fc40623fa8;

    CurveCoordinates internal _curve;
    Asset            internal _etherLP;
    Asset            internal _shardLP;
    address          internal _wallet;
    uint256          internal _decimals;
    address          internal _recipient;
    uint256          internal _deadline;

    event Initialized(address wallet);
    event ShardsBought(address indexed account, uint256 amount, uint256 cost);
    event ShardsSold(address indexed account, uint256 amount, uint256 payout);
    event ShardsSupplied(address indexed provider, uint256 amount);
    event EtherSupplied(address indexed provider, uint256 amount);
    event ShardsWithdrawn(address indexed provider, uint256 payout, uint256 shards);
    event EtherWithdrawn(address indexed provider, uint256 value, uint256 payout);
    event TransferEthLPTokens(address indexed sender, address indexed recipient, uint256 amount);
    event TransferShardLPTokens(address indexed sender, address indexed recipient, uint256 amount);

    function initialize(
        uint256 supply,
        address wallet,
        address recipient,
        uint256 price
    )
    public payable
    {
        require(_wallet == address(0));
        uint256 totalSupply_ = ShardedWallet(payable(wallet)).totalSupply();
        uint256 decimals_    = ShardedWallet(payable(wallet)).decimals();

        // setup params
        _wallet    = wallet;
        _decimals  = decimals_;
        _recipient = recipient;
        _deadline  = block.timestamp + ShardedWallet(payable(wallet)).governance().getConfig(wallet, LIQUIDITY_TIMELOCK);
        emit Initialized(_wallet);

        // transfer assets
        if (supply > 0) {
            require(ShardedWallet(payable(wallet)).transferFrom(msg.sender, address(this), supply));
        }

        // setup curve
        _curve.x = totalSupply_;
        _curve.k = totalSupply_ * totalSupply_ * price / 10**decimals_;

        // mint liquidity
        _mintShardLP(address(this), supply);
        _mintEthLP(address(this), msg.value);
        _shardLP.underlyingSupply = supply;
        _etherLP.underlyingSupply = msg.value;
        emit ShardsSupplied(address(this), supply);
        emit EtherSupplied(address(this), msg.value);
    }

    function buyShards(uint256 amount, uint256 maxCost) public payable {
        uint256 cost = _buyShards(msg.sender, amount, maxCost);

        require(cost <= msg.value);
        if (msg.value > cost) {
            Address.sendValue(payable(msg.sender), msg.value - cost);
        }
    }

    function sellShards(uint256 amount, uint256 minPayout) public {
        require(ShardedWallet(payable(_wallet)).transferFrom(msg.sender, address(this), amount));
        _sellShards(msg.sender, amount, minPayout);
    }

    function supplyEther() public payable {
        _supplyEther(msg.sender, msg.value);
    }

    function supplyShards(uint256 amount) public {
        require(ShardedWallet(payable(_wallet)).transferFrom(msg.sender, address(this), amount));
        _supplyShards(msg.sender, amount);
    }

    function onApprovalReceived(address owner, uint256 amount, bytes calldata data) public override returns (bytes4) {
        require(msg.sender == _wallet, "onApprovalReceived restricted to token contract");
        require(ShardedWallet(payable(_wallet)).transferFrom(owner, address(this), amount));

        bytes4 selector = abi.decode(data, (bytes4));
        if (selector == this.sellShards.selector) {
            (,uint256 minPayout) = abi.decode(data, (bytes4, uint256));
            _sellShards(owner, amount, minPayout);
        } else if (selector == this.supplyShards.selector) {
            _supplyShards(owner, amount);
        } else {
            revert("invalid selector in onApprovalReceived data");
        }

        return this.onApprovalReceived.selector;
    }

    function _buyShards(address buyer, uint256 amount, uint256 maxCost) internal returns (uint256) {
        IGovernance governance = ShardedWallet(payable(_wallet)).governance();
        address     owner      = ShardedWallet(payable(_wallet)).owner();
        address     artist     = ShardedWallet(payable(_wallet)).artistWallet();

        // pause if someone else reclaimed the ownership of shardedWallet
        require(owner == address(0) || governance.isModule(_wallet, owner));

        // compute fees
        uint256[3] memory fees;
        fees[0] =                            governance.getConfig(_wallet, PCT_FEE_SUPPLIERS);
        fees[1] =                            governance.getConfig(_wallet, PCT_FEE_NIFTEX);
        fees[2] = artist == address(0) ? 0 : governance.getConfig(_wallet, PCT_FEE_ARTIST);

        uint256 amountWithFee = amount * (10**18 + fees[0] + fees[1] + fees[2]) / 10**18;

        // check curve update
        uint256 newX = _curve.x - amountWithFee;
        uint256 newY = _curve.k / newX;
        require(newX > 0 && newY > 0);

        // check cost
        uint256 cost = newY - _curve.k / _curve.x;
        require(cost <= maxCost);

        // consistency check
        require(ShardedWallet(payable(_wallet)).balanceOf(address(this)) - _shardLP.feeToNiftex - _shardLP.feeToArtist >= amountWithFee);

        // update curve
        _curve.x -= amount * (10**18 + fees[1] + fees[2]) / 10**18;

        // update LP supply
        _shardLP.underlyingSupply += amount * fees[0] / 10**18;
        _shardLP.feeToNiftex      += amount * fees[1] / 10**18;
        _shardLP.feeToArtist      += amount * fees[2] / 10**18;

        // transfer
        ShardedWallet(payable(_wallet)).transfer(buyer, amount);

        emit ShardsBought(buyer, amount, cost);
        return cost;
    }

    function _sellShards(address seller, uint256 amount, uint256 minPayout) internal returns (uint256) {
        IGovernance governance = ShardedWallet(payable(_wallet)).governance();
        address     owner      = ShardedWallet(payable(_wallet)).owner();
        address     artist     = ShardedWallet(payable(_wallet)).artistWallet();

        // pause if someone else reclaimed the ownership of shardedWallet
        require(owner == address(0) || governance.isModule(_wallet, owner));

        // compute fees
        uint256[3] memory fees;
        fees[0] =                            governance.getConfig(_wallet, PCT_FEE_SUPPLIERS);
        fees[1] =                            governance.getConfig(_wallet, PCT_FEE_NIFTEX);
        fees[2] = artist == address(0) ? 0 : governance.getConfig(_wallet, PCT_FEE_ARTIST);

        uint256 newX = _curve.x + amount;
        uint256 newY = _curve.k / newX;
        require(newX > 0 && newY > 0);

        // check payout
        uint256 payout = _curve.k / _curve.x - newY;
        require(payout <= address(this).balance - _etherLP.feeToNiftex - _etherLP.feeToArtist && payout >= minPayout);
        uint256 value = payout * (10**18 - fees[0] - fees[1] - fees[2]) / 10**18;

        // update curve
        _curve.x = newX;

        // update LP supply
        _etherLP.underlyingSupply += payout * fees[0] / 10**18;
        _etherLP.feeToNiftex      += payout * fees[1] / 10**18;
        _etherLP.feeToArtist      += payout * fees[2] / 10**18;

        // transfer
        Address.sendValue(payable(seller), value);

        emit ShardsSold(seller, amount, value);
        return value;
    }

    function _supplyEther(address supplier, uint256 amount) internal {
        require(_curve.k / _curve.x >= address(this).balance);

        _mintEthLP(supplier, calcNewEthLPTokensToIssue(amount));
        _etherLP.underlyingSupply += amount;

        emit EtherSupplied(supplier, amount);
    }


    function _supplyShards(address supplier, uint256 amount) internal {
        require(_curve.x >= _shardLP.underlyingSupply + amount);

        _mintShardLP(supplier, calcNewShardLPTokensToIssue(amount));
        _shardLP.underlyingSupply += amount;

        emit ShardsSupplied(supplier, amount);
    }

    function calcNewShardLPTokensToIssue(uint256 amount) public view returns (uint256) {
        uint256 pool = _shardLP.underlyingSupply;
        if (pool == 0) { return amount; }
        uint256 proportion = amount * 10**18 / (pool + amount);
        return proportion * _shardLP.totalSupply / (10**18 - proportion);
    }

    function calcNewEthLPTokensToIssue(uint256 amount) public view returns (uint256) {
        uint256 pool = _etherLP.underlyingSupply;
        if (pool == 0) { return amount; }
        uint256 proportion = amount * 10**18 / (pool + amount);
        return proportion * _etherLP.totalSupply / (10**18 - proportion);
    }

    function calcShardsForEthSuppliers() public view returns (uint256) {
        uint256 balance = ShardedWallet(payable(_wallet)).balanceOf(address(this)) - _shardLP.feeToNiftex - _shardLP.feeToArtist;
        return balance < _shardLP.underlyingSupply ? 0 : balance - _shardLP.underlyingSupply;
    }

    function calcEthForShardSuppliers() public view returns (uint256) {
        uint256 balance = address(this).balance - _etherLP.feeToNiftex - _etherLP.feeToArtist;
        return balance < _etherLP.underlyingSupply ? 0 : balance - _etherLP.underlyingSupply;
    }

    function withdrawSuppliedEther(uint256 amount) external returns (uint256, uint256) {
        require(amount > 0);

        uint256 etherLPSupply = _etherLP.totalSupply;

        uint256 balance = address(this).balance - _etherLP.feeToNiftex - _etherLP.feeToArtist;

        uint256 value = (balance <= _etherLP.underlyingSupply)
        ? balance * amount / etherLPSupply
        : _etherLP.underlyingSupply * amount / etherLPSupply;

        uint256 payout = calcShardsForEthSuppliers() * amount / etherLPSupply;

        // update balances
        _etherLP.underlyingSupply *= etherLPSupply - amount;
        _etherLP.underlyingSupply /= etherLPSupply;
        _burnEthLP(msg.sender, amount);

        // transfer
        Address.sendValue(payable(msg.sender), value);
        if (payout > 0) {
            ShardedWallet(payable(_wallet)).transfer(msg.sender, payout);
        }

        emit EtherWithdrawn(msg.sender, value, payout);

        return (value, payout);
    }

    function withdrawSuppliedShards(uint256 amount) external returns (uint256, uint256) {
        require(amount > 0);

        uint256 shardLPSupply = _shardLP.totalSupply;

        uint256 balance = ShardedWallet(payable(_wallet)).balanceOf(address(this)) - _shardLP.feeToNiftex - _shardLP.feeToArtist;

        uint256 shards = (balance <= _shardLP.underlyingSupply)
        ? balance * amount / shardLPSupply
        : _shardLP.underlyingSupply * amount / shardLPSupply;

        uint256 payout = calcEthForShardSuppliers() * amount / shardLPSupply;

        // update balances
        _shardLP.underlyingSupply *= shardLPSupply - amount;
        _shardLP.underlyingSupply /= shardLPSupply;
        _burnShardLP(msg.sender, amount);

        // transfer
        ShardedWallet(payable(_wallet)).transfer(msg.sender, shards);
        if (payout > 0) {
            Address.sendValue(payable(msg.sender), payout);
        }

        emit ShardsWithdrawn(msg.sender, payout, shards);

        return (payout, shards);
    }

    function withdrawNiftexOrArtistFees(address recipient) public {
        uint256 etherFees = 0;
        uint256 shardFees = 0;

        if (msg.sender == ShardedWallet(payable(_wallet)).artistWallet()) {
            etherFees += _etherLP.feeToArtist;
            shardFees += _shardLP.feeToArtist;
            delete _etherLP.feeToArtist;
            delete _shardLP.feeToArtist;
        }

        if (msg.sender == ShardedWallet(payable(_wallet)).governance().getNiftexWallet()) {
            etherFees += _etherLP.feeToNiftex;
            shardFees += _shardLP.feeToNiftex;
            delete _etherLP.feeToNiftex;
            delete _shardLP.feeToNiftex;
        }

        Address.sendValue(payable(recipient), etherFees);
        ShardedWallet(payable(_wallet)).transfer(recipient, shardFees);
    }

    function transferTimelockLiquidity() public {
        require(_deadline < block.timestamp);
        _transferEthLP(address(this), _recipient, getEthLPTokens(address(this)));
        _transferShardLP(address(this), _recipient, getShardLPTokens(address(this)));
    }

    function getEthLPTokens(address owner) public view returns (uint256) {
        return _etherLP.balance[owner];
    }

    function getShardLPTokens(address owner) public view returns (uint256) {
        return _shardLP.balance[owner];
    }

    function transferEthLPTokens(address recipient, uint256 amount) public {
        _transferShardLP(msg.sender, recipient, amount);
    }

    function transferShardLPTokens(address recipient, uint256 amount) public {
        _transferEthLP(msg.sender, recipient, amount);
    }

    function _transferEthLP(address sender, address recipient, uint256 amount) internal {
        _etherLP.balance[sender]    -= amount;
        _etherLP.balance[recipient] += amount;
        emit TransferEthLPTokens(sender, recipient, amount);
    }

    function _mintEthLP(address account, uint256 amount) internal {
        _etherLP.balance[account] += amount;
        _etherLP.totalSupply      += amount;
        emit TransferEthLPTokens(address(0), account, amount);
    }

    function _burnEthLP(address account, uint256 amount) internal {
        _etherLP.balance[account] -= amount;
        _etherLP.totalSupply      -= amount;
        emit TransferEthLPTokens(account, address(0), amount);
    }

    function _transferShardLP(address sender, address recipient, uint256 amount) internal {
        _shardLP.balance[sender]    -= amount;
        _shardLP.balance[recipient] += amount;
        emit TransferShardLPTokens(sender, recipient, amount);
    }

    function _mintShardLP(address account, uint256 amount) internal {
        _shardLP.balance[account] += amount;
        _shardLP.totalSupply      += amount;
        emit TransferShardLPTokens(address(0), account, amount);
    }

    function _burnShardLP(address account, uint256 amount) internal {
        _shardLP.balance[account] -= amount;
        _shardLP.totalSupply      -= amount;
        emit TransferShardLPTokens(account, address(0), amount);
    }

    function getCurrentPrice() external view returns (uint256) {
        return _curve.k * 10**_decimals / _curve.x / _curve.x;
    }

    function getCurveCoordinates() external view returns (uint256, uint256) {
        return (_curve.x, _curve.k);
    }

    function getEthSuppliers() external view returns (uint256, uint256, uint256, uint256) {
        return (_etherLP.underlyingSupply, _etherLP.totalSupply, _etherLP.feeToNiftex, _etherLP.feeToArtist);
    }

    function getShardSuppliers() external view returns (uint256, uint256, uint256, uint256) {
        return (_shardLP.underlyingSupply, _shardLP.totalSupply, _shardLP.feeToNiftex, _shardLP.feeToArtist);
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }
}
