// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ERC20.sol";
import "../wallet/ShardedWallet.sol";
import "../governance/IGovernance.sol";
import "../interface/IERC1363Receiver.sol";
import "../interface/IERC1363Spender.sol";

contract LiquidityToken is ERC20 {
    address public controler;

    modifier onlyControler() {
        require(msg.sender == controler);
        _;
    }

    constructor() {
        controler = address(0xdead);
    }

    function initialize(address controler_, string memory name_, string memory symbol_) public {
        require(controler == address(0));
        controler = controler_;
        _initialize(name_, symbol_);
    }

    function controllerTransfer(address sender, address recipient, uint256 amount) public onlyControler {
        _transfer(sender, recipient, amount);
    }

    function controllerMint(address account, uint256 amount) public onlyControler {
        _mint(account, amount);
    }

    function controllerBurn(address account, uint256 amount) public onlyControler {
        _burn(account, amount);
    }
}

contract BondingCurve3 is IERC1363Spender {
    struct CurveCoordinates {
        uint256 x;
        uint256 k;
    }

    struct Asset {
        uint256 underlyingSupply;
        uint256 feeToNiftex;
        uint256 feeToArtist;
    }

    LiquidityToken immutable internal _template;

    // bytes32 public constant PCT_FEE_SUPPLIERS = bytes32(uint256(keccak256("PCT_FEE_SUPPLIERS")) - 1);
    bytes32 public constant PCT_FEE_SUPPLIERS  = 0xe4f5729eb40e38b5a39dfb36d76ead9f9bc286f06852595980c5078f1af7e8c9;
    // bytes32 public constant PCT_FEE_ARTIST    = bytes32(uint256(keccak256("PCT_FEE_ARTIST")) - 1);
    bytes32 public constant PCT_FEE_ARTIST     = 0xdd0618e2e2a17ff193a933618181c8f8909dc169e9707cce1921893a88739ca0;
    // bytes32 public constant PCT_FEE_NIFTEX    = bytes32(uint256(keccak256("PCT_FEE_NIFTEX")) - 1);
    bytes32 public constant PCT_FEE_NIFTEX     = 0xcfb1dd89e6f4506eca597e7558fbcfe22dbc7e0b9f2b3956e121d0e344d6f7aa;
    // bytes32 public constant LIQUIDITY_TIMELOCK   = bytes32(uint256(keccak256("LIQUIDITY_TIMELOCK")) - 1);
    bytes32 public constant LIQUIDITY_TIMELOCK = 0x4babff57ebd34f251a515a845400ed950a51f0a64c92e803a3e144fc40623fa8;

    LiquidityToken   public   etherLPToken;
    LiquidityToken   public   shardLPToken;
    CurveCoordinates public   curve;
    Asset            internal _etherLPExtra;
    Asset            internal _shardLPExtra;
    address          public   wallet;
    address          public   recipient;
    uint256          public   deadline;

    event Initialized(address wallet);
    event ShardsBought(address indexed account, uint256 amount, uint256 cost);
    event ShardsSold(address indexed account, uint256 amount, uint256 payout);
    event ShardsSupplied(address indexed provider, uint256 amount);
    event EtherSupplied(address indexed provider, uint256 amount);
    event ShardsWithdrawn(address indexed provider, uint256 payout, uint256 shards);
    event EtherWithdrawn(address indexed provider, uint256 value, uint256 payout);

    constructor() {
        _template = new LiquidityToken();
        wallet = address(0xdead);
    }

    function initialize(
        uint256 supply,
        address wallet_,
        address recipient_,
        uint256 price
    )
    public payable
    {
        require(wallet == address(0));
        uint256 totalSupply_  = ShardedWallet(payable(wallet_)).totalSupply();
        string memory name_   = ShardedWallet(payable(wallet_)).name();
        string memory symbol_ = ShardedWallet(payable(wallet_)).symbol();

        etherLPToken = LiquidityToken(Clones.clone(address(_template)));
        shardLPToken = LiquidityToken(Clones.clone(address(_template)));
        etherLPToken.initialize(address(this), string(abi.encodePacked(name_, "-EtherLP")), string(abi.encodePacked(symbol_, "-ELP")));
        shardLPToken.initialize(address(this), string(abi.encodePacked(name_, "-ShardLP")), string(abi.encodePacked(symbol_, "-SLP")));

        wallet    = wallet_;
        recipient = recipient_;
        deadline  = block.timestamp + ShardedWallet(payable(wallet_)).governance().getConfig(wallet_, LIQUIDITY_TIMELOCK);
        emit Initialized(wallet_);

        // transfer assets
        if (supply > 0) {
            require(ShardedWallet(payable(wallet_)).transferFrom(msg.sender, address(this), supply));
        }

        // setup curve
        curve.x = totalSupply_;
        curve.k = totalSupply_ * totalSupply_ * price / 10**18;

        // mint liquidity
        etherLPToken.controllerMint(address(this), msg.value);
        shardLPToken.controllerMint(address(this), supply);
        _etherLPExtra.underlyingSupply = msg.value;
        _shardLPExtra.underlyingSupply = supply;
        emit EtherSupplied(address(this), msg.value);
        emit ShardsSupplied(address(this), supply);
    }

    function buyShards(uint256 amount, uint256 maxCost) public payable {
        uint256 cost = _buyShards(msg.sender, amount, maxCost);

        require(cost <= msg.value);
        if (msg.value > cost) {
            Address.sendValue(payable(msg.sender), msg.value - cost);
        }
    }

    function sellShards(uint256 amount, uint256 minPayout) public {
        require(ShardedWallet(payable(wallet)).transferFrom(msg.sender, address(this), amount));
        _sellShards(msg.sender, amount, minPayout);
    }

    function supplyEther() public payable {
        _supplyEther(msg.sender, msg.value);
    }

    function supplyShards(uint256 amount) public {
        require(ShardedWallet(payable(wallet)).transferFrom(msg.sender, address(this), amount));
        _supplyShards(msg.sender, amount);
    }

    function onApprovalReceived(address owner, uint256 amount, bytes calldata data) public override returns (bytes4) {
        require(ShardedWallet(payable(wallet)).transferFrom(owner, address(this), amount));

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
        IGovernance governance = ShardedWallet(payable(wallet)).governance();
        address     owner      = ShardedWallet(payable(wallet)).owner();
        address     artist     = ShardedWallet(payable(wallet)).artistWallet();

        // pause if someone else reclaimed the ownership of shardedWallet
        require(owner == address(0) || governance.isModule(wallet, owner));

        // compute fees
        uint256[3] memory fees;
        fees[0] =                            governance.getConfig(wallet, PCT_FEE_SUPPLIERS);
        fees[1] =                            governance.getConfig(wallet, PCT_FEE_NIFTEX);
        fees[2] = artist == address(0) ? 0 : governance.getConfig(wallet, PCT_FEE_ARTIST);

        uint256 amountWithFee = amount * (10**18 + fees[0] + fees[1] + fees[2]) / 10**18;

        // check curve update
        uint256 newX = curve.x - amountWithFee;
        uint256 newY = curve.k / newX;
        require(newX > 0 && newY > 0);

        // check cost
        uint256 cost = newY - curve.k / curve.x;
        require(cost <= maxCost);

        // consistency check
        require(ShardedWallet(payable(wallet)).balanceOf(address(this)) - _shardLPExtra.feeToNiftex - _shardLPExtra.feeToArtist >= amount * (10**18 + fees[1] + fees[2]) / 10**18);

        // update curve
        curve.x = curve.x - amount * (10**18 + fees[1] + fees[2]) / 10**18;

        // update LP supply
        _shardLPExtra.underlyingSupply += amount * fees[0] / 10**18;
        _shardLPExtra.feeToNiftex      += amount * fees[1] / 10**18;
        _shardLPExtra.feeToArtist      += amount * fees[2] / 10**18;

        // transfer
        ShardedWallet(payable(wallet)).transfer(buyer, amount);

        emit ShardsBought(buyer, amount, cost);
        return cost;
    }

    function _sellShards(address seller, uint256 amount, uint256 minPayout) internal returns (uint256) {
        IGovernance governance = ShardedWallet(payable(wallet)).governance();
        address     owner      = ShardedWallet(payable(wallet)).owner();
        address     artist     = ShardedWallet(payable(wallet)).artistWallet();

        // pause if someone else reclaimed the ownership of shardedWallet
        require(owner == address(0) || governance.isModule(wallet, owner));

        // compute fees
        uint256[3] memory fees;
        fees[0] =                            governance.getConfig(wallet, PCT_FEE_SUPPLIERS);
        fees[1] =                            governance.getConfig(wallet, PCT_FEE_NIFTEX);
        fees[2] = artist == address(0) ? 0 : governance.getConfig(wallet, PCT_FEE_ARTIST);

        uint256 newX = curve.x + amount;
        uint256 newY = curve.k / newX;
        require(newX > 0 && newY > 0);

        // check payout
        uint256 payout = curve.k / curve.x - newY;
        require(payout <= address(this).balance - _etherLPExtra.feeToNiftex - _etherLPExtra.feeToArtist);
        uint256 value = payout * (10**18 - fees[0] - fees[1] - fees[2]) / 10**18;
        require(value >= minPayout);

        // update curve
        curve.x = newX;

        // update LP supply
        _etherLPExtra.underlyingSupply += payout * fees[0] / 10**18;
        _etherLPExtra.feeToNiftex      += payout * fees[1] / 10**18;
        _etherLPExtra.feeToArtist      += payout * fees[2] / 10**18;

        // transfer
        Address.sendValue(payable(seller), value);

        emit ShardsSold(seller, amount, value);
        return value;
    }

    function _supplyEther(address supplier, uint256 amount) internal {
        require(curve.k / curve.x >= address(this).balance);

        etherLPToken.controllerMint(supplier, calcNewEthLPTokensToIssue(amount));
        _etherLPExtra.underlyingSupply += amount;

        emit EtherSupplied(supplier, amount);
    }


    function _supplyShards(address supplier, uint256 amount) internal {
        require(curve.x >= ShardedWallet(payable(wallet)).balanceOf(address(this)));

        shardLPToken.controllerMint(supplier, calcNewShardLPTokensToIssue(amount));
        _shardLPExtra.underlyingSupply += amount;

        emit ShardsSupplied(supplier, amount);
    }

    function calcNewShardLPTokensToIssue(uint256 amount) public view returns (uint256) {
        uint256 pool = _shardLPExtra.underlyingSupply;
        if (pool == 0) { return amount; }
        uint256 proportion = amount * 10**18 / (pool + amount);
        return proportion * shardLPToken.totalSupply() / (10**18 - proportion);
    }

    function calcNewEthLPTokensToIssue(uint256 amount) public view returns (uint256) {
        uint256 pool = _etherLPExtra.underlyingSupply;
        if (pool == 0) { return amount; }
        uint256 proportion = amount * 10**18 / (pool + amount);
        return proportion * etherLPToken.totalSupply() / (10**18 - proportion);
    }

    function calcShardsForEthSuppliers() public view returns (uint256) {
        uint256 balance = ShardedWallet(payable(wallet)).balanceOf(address(this)) - _shardLPExtra.feeToNiftex - _shardLPExtra.feeToArtist;
        return balance < _shardLPExtra.underlyingSupply ? 0 : balance - _shardLPExtra.underlyingSupply;
    }

    function calcEthForShardSuppliers() public view returns (uint256) {
        uint256 balance = address(this).balance - _etherLPExtra.feeToNiftex - _etherLPExtra.feeToArtist;
        return balance < _etherLPExtra.underlyingSupply ? 0 : balance - _etherLPExtra.underlyingSupply;
    }

    function withdrawSuppliedEther(uint256 amount) external returns (uint256, uint256) {
        require(amount > 0);

        uint256 etherLPTokenSupply = etherLPToken.totalSupply();

        uint256 balance = address(this).balance - _etherLPExtra.feeToNiftex - _etherLPExtra.feeToArtist;

        uint256 value = (balance <= _etherLPExtra.underlyingSupply)
        ? balance * amount / etherLPTokenSupply
        : _etherLPExtra.underlyingSupply * amount / etherLPTokenSupply;

        uint256 payout = calcShardsForEthSuppliers() * amount / etherLPTokenSupply;

        // update balances
        _etherLPExtra.underlyingSupply *= etherLPTokenSupply - amount;
        _etherLPExtra.underlyingSupply /= etherLPTokenSupply;
        etherLPToken.controllerBurn(msg.sender, amount);

        // transfer
        Address.sendValue(payable(msg.sender), value);
        if (payout > 0) {
            ShardedWallet(payable(wallet)).transfer(msg.sender, payout);
        }

        emit EtherWithdrawn(msg.sender, value, payout);

        return (value, payout);
    }

    function withdrawSuppliedShards(uint256 amount) external returns (uint256, uint256) {
        require(amount > 0);

        uint256 shardLPTokenSupply = shardLPToken.totalSupply();

        uint256 balance = ShardedWallet(payable(wallet)).balanceOf(address(this)) - _shardLPExtra.feeToNiftex - _shardLPExtra.feeToArtist;

        uint256 shards = (balance <= _shardLPExtra.underlyingSupply)
        ? balance * amount / shardLPTokenSupply
        : _shardLPExtra.underlyingSupply * amount / shardLPTokenSupply;

        uint256 payout = calcEthForShardSuppliers() * amount / shardLPTokenSupply;

        // update balances
        _shardLPExtra.underlyingSupply *= shardLPTokenSupply - amount;
        _shardLPExtra.underlyingSupply /= shardLPTokenSupply;
        shardLPToken.controllerBurn(msg.sender, amount);

        // transfer
        ShardedWallet(payable(wallet)).transfer(msg.sender, shards);
        if (payout > 0) {
            Address.sendValue(payable(msg.sender), payout);
        }

        emit ShardsWithdrawn(msg.sender, payout, shards);

        return (payout, shards);
    }

    function withdrawNiftexOrArtistFees(address to) public {
        uint256 etherFees = 0;
        uint256 shardFees = 0;

        if (msg.sender == ShardedWallet(payable(wallet)).artistWallet()) {
            etherFees += _etherLPExtra.feeToArtist;
            shardFees += _shardLPExtra.feeToArtist;
            delete _etherLPExtra.feeToArtist;
            delete _shardLPExtra.feeToArtist;
        }

        if (msg.sender == ShardedWallet(payable(wallet)).governance().getNiftexWallet()) {
            etherFees += _etherLPExtra.feeToNiftex;
            shardFees += _shardLPExtra.feeToNiftex;
            delete _etherLPExtra.feeToNiftex;
            delete _shardLPExtra.feeToNiftex;
        }

        Address.sendValue(payable(to), etherFees);
        ShardedWallet(payable(wallet)).transfer(to, shardFees);
    }

    function transferTimelockLiquidity() public {
        require(deadline < block.timestamp);
        etherLPToken.controllerTransfer(address(this), recipient, getEthLPTokens(address(this)));
        shardLPToken.controllerTransfer(address(this), recipient, getShardLPTokens(address(this)));
    }

    function getEthLPTokens(address owner) public view returns (uint256) {
        return etherLPToken.balanceOf(owner);
    }

    function getShardLPTokens(address owner) public view returns (uint256) {
        return shardLPToken.balanceOf(owner);
    }

    function transferEthLPTokens(address to, uint256 amount) public {
        etherLPToken.controllerTransfer(msg.sender, to, amount);
    }

    function transferShardLPTokens(address to, uint256 amount) public {
        shardLPToken.controllerTransfer(msg.sender, to, amount);
    }

    function getCurrentPrice() external view returns (uint256) {
        return curve.k * 10**18 / curve.x / curve.x;
    }

    function getEthSuppliers() external view returns (uint256, uint256, uint256, uint256) {
        return (_etherLPExtra.underlyingSupply, etherLPToken.totalSupply(), _etherLPExtra.feeToNiftex, _etherLPExtra.feeToArtist);
    }

    function getShardSuppliers() external view returns (uint256, uint256, uint256, uint256) {
        return (_shardLPExtra.underlyingSupply, shardLPToken.totalSupply(), _shardLPExtra.feeToNiftex, _shardLPExtra.feeToArtist);
    }
}
