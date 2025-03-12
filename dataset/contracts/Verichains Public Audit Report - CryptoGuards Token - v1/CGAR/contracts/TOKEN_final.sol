// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

import "./helpers/Limiter.sol";


contract CGAR is Initializable, ERC20Upgradeable, PausableUpgradeable, OwnableUpgradeable {

    address private _rewardAddress; // For deposit

    address private _feeReceiveAddress; // For fee charge
    uint256 private _buyFee; // Per-mille
    uint256 private _sellFee; // Per-mille

    address private _pancakeLPAddress; // For Fee on Pancake

    address private _pancakeRouterAddress;

    Limiter private _limiter;

    address private _lpCreatorAddress;
    bool private _isLockTransferForAntiBot;

    mapping(address => bool) _lpAddresses;

    event Deposit(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC20_init("CryptoGuards", "CGAR");
        __Pausable_init();
        __Ownable_init();

        // Buy/Sell fee
        _buyFee = 0 * (10 ** (decimals() - 1));
        _sellFee = 200 * (10 ** (decimals() - 1));

        // Address
        _rewardAddress = address(0);
        _feeReceiveAddress = address(0);
        _pancakeLPAddress = address(0);
        _isLockTransferForAntiBot = false;
        _lpCreatorAddress = address(0);
        _pancakeRouterAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

        _limiter = new Limiter(
            500 * (10 ** decimals()),
            300 * (10 ** decimals()),
            2500 * (10 ** decimals())
        );

        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
    // BUY/SELL FEE
    function setBuyFee(uint256 fee) public onlyOwner {
        _buyFee = fee;
    }
    function setSellFee(uint256 _fee) public onlyOwner {
        _sellFee = _fee;
    }
    function getFees() external view returns(uint256 buyFee, uint256 sellFee) {
        return (_buyFee, _sellFee);
    }
    // REWARDS:
    function setRewardAddress(address newAddress) public onlyOwner {
        require(newAddress != address(0), "ERC20: Invalid reward address");
        _rewardAddress = newAddress;
    }
    // FEE RECEIVE ADDRESS
    function setFeeReceiveAddress(address addr) public onlyOwner {
        require(addr != address(0), "ERC20: Invalid receive address");
        _feeReceiveAddress = addr;
    }

    function getAddressesData() external view returns(
        address reward,
        address fee,
        address pancakeLP
    ) {
        return (_rewardAddress, _feeReceiveAddress, _pancakeLPAddress);
    }

    // MAX BUY/SELL
    function setMaxBuy(uint256 max) public onlyOwner {
        _limiter.setMaxBuyLimit(max);
    }

    function setMaxSell(uint256 max) public onlyOwner {
        _limiter.setMaxSellLimit(max);
    }
    function setLimitBuy(uint256 _limit) public onlyOwner {
        _limiter.setLimitBuy(_limit);
    }

    function getLimitData() external view returns(
        uint256 maxBuy, uint256 maxSell, uint256 totalBuy
    ) {
       return (_limiter.getMaxBuy(), _limiter.getMaxSell(), _limiter.getLimitBuy());
    }

    function getAddressTotalBuy(address _sender) public view virtual returns(int256) {
        return _limiter.getAddressTotalBuy(_sender);
    }

    // DEPOSIT
    function deposit(uint256 amount) external virtual {
        require(_rewardAddress != address(0) && _msgSender() != address(0), "ERC20: Invalid address");
        transfer(_rewardAddress, amount);
        emit Deposit(_msgSender(), amount);
    }

    // WITHDRAW
    function withdraw(address recipient, uint256 amount) external virtual {
        require(_msgSender() != address(0) && _msgSender() == _rewardAddress, "CGAR: Invalid sender");
        transfer(recipient, amount);
        emit Withdraw(_msgSender(), amount);
    }

    // OVERRIDE FOR FEE TRANSFER
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        require(!_isLockTransferForAntiBot || sender == _lpCreatorAddress, "CGAR: Antibot revert");
        if (isAddressLP(recipient)) {
            // SELL
            uint256 _fee = 0;
            if (sender != _lpCreatorAddress) {
                require(_limiter.isValidSell(amount), "CGAR: Sell limit reach");
                _fee = calculateFee(amount, _sellFee);
            }
            return _transferFrom(sender, recipient, amount, _fee, _feeReceiveAddress);
        }
        return _transferFrom(sender, recipient, amount, 0, address(0));
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (isAddressLP(_msgSender()) || isAddressLP(recipient)) {
            // BUY
            require(!_isLockTransferForAntiBot || recipient == _lpCreatorAddress, "CGAR: Antibot revert");
            uint256 _fee = 0;
            if (recipient != _lpCreatorAddress && recipient != _pancakeRouterAddress) {
                require(_limiter.isValidBuy(recipient, amount), "CGAR: Buy limit reach");
                _fee = calculateFee(amount, _buyFee);
                if (isAddressLP(recipient)) {
                    _fee = calculateFee(amount, _sellFee);
                }
            }
            _transfer(_msgSender(), recipient, amount, _fee, _feeReceiveAddress);
            if (recipient != _lpCreatorAddress) {
                _limiter.onBuySuccess(recipient, amount);
            }
        } else {
            require(recipient != address(this), "CGAR: Failed to transfer");
            _transfer(_msgSender(), recipient, amount, 0, address(0));
        }
        return true;
    }

    function calculateFee(uint256 amount, uint256 _fee) private view returns(uint256) {
        uint fraction = decimals() + 2;
        return amount * _fee / (10 ** fraction);
    }

    function setLPCreatorAddress(address _addr) external onlyOwner {
        require(_addr != address(0), "ERC20: Invalid reward address");
        _lpCreatorAddress = _addr;
    }

    function setEnableAntibot(bool enable) external onlyOwner {
        _isLockTransferForAntiBot = enable;
    }

    function getAntibotData() external view returns(bool isEnable, address lpCreator) {
        return (_isLockTransferForAntiBot, _lpCreatorAddress);
    }

    function setLPAddress(address _addr, bool enable) external onlyOwner {
        require(_addr != address(0), "ERC20: Invalid lp address");
        _lpAddresses[_addr] = enable;
    }

    function isAddressLP(address _addr) public view returns(bool) {
        return _lpAddresses[_addr];
    }
}
