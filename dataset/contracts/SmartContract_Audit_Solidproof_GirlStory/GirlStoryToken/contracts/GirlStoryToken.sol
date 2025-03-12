// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract BPContract {
    function protect(
        address sender,
        address receiver,
        uint256 amount
    ) external virtual;
}

contract GirlStoryToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcluded;

    address private _dev = 0xDFC49D58af372769A77197CcC2e807808C517AA6;

    string private constant _name = "GIRL STORY";
    string private constant _symbol = "GSY";
    uint8 private constant _decimals = 18;

    uint256 private _totalSupply = 10000000 * 10**uint256(_decimals);
    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;

    bool public bpEnabled;
    BPContract BP;

    uint256 private _devr = 200;
    mapping(address => bool) public blacklist;

    event EventExcludeAddress(address indexed account);
    event EventRemoveExcludeAddress(address indexed account);
    event EventSetDevReward(uint256 devf);

    constructor() public {
        _balances[_msgSender()] = _balances[_msgSender()].add(_totalSupply);
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    function multiBlacklist(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = true;
        }
    }

    function multiRemoveFromBlacklist(address[] memory addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = false;
        }
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        _transfer(sender, recipient, amount);
        return true;
    }

    function findPercent(uint256 value, uint256 fee)
        public
        pure
        returns (uint256)
    {
        uint256 roundValue = ceil(value, fee);
        uint256 TPercent = roundValue.mul(fee).div(10000);
        return TPercent;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function totalBurn() public view returns (uint256) {
        return _tBurnTotal;
    }

    function _reflectFee(uint256 tFee) private {
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= _balances[sender],
            "ERC20: amount must be less or equal to balance"
        );
        require(!blacklist[sender] && !blacklist[recipient]);

        if (bpEnabled) {
            //
            BP.protect(sender, recipient, amount);
        }

        if (_isExcluded[sender] != true) {
            uint256 tFee = findPercent(amount, _devr);
            uint256 tokensToTransfer = amount.sub(tFee);

            _balances[sender] = _balances[sender].sub(amount);
            _balances[recipient] = _balances[recipient].add(tokensToTransfer);
            _balances[_dev] = _balances[_dev].add(tFee);

            _reflectFee(tFee);
            emit Transfer(sender, recipient, tokensToTransfer);
            emit Transfer(sender, _dev, tFee);
        } else {
            _balances[sender] = _balances[sender].sub(amount);
            _balances[recipient] = _balances[recipient].add(amount);
            emit Transfer(sender, recipient, amount);
        }
    }

    function multiTransfer(address[] memory receivers, uint256[] memory amounts)
        public
    {
        for (uint256 i = 0; i < receivers.length; i++) {
            transfer(receivers[i], amounts[i]);
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(amount != 0);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(amount != 0);
        require(amount <= _balances[account]);
        _totalSupply = _totalSupply.sub(amount);
        _tBurnTotal = _tBurnTotal.add(amount);
        _balances[account] = _balances[account].sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function burnFrom(address account, uint256 amount) external onlyOwner {
        require(amount <= _allowances[account][_msgSender()]);
        _allowances[account][_msgSender()] = _allowances[account][_msgSender()]
            .sub(amount);
        _burn(account, amount);
    }

    function _getdevReward() public view returns (uint256) {
        return _devr;
    }

    function _setdevReward(uint256 devf) external onlyOwner {
        _devr = devf;
        emit EventSetDevReward(_devr);
    }

    function ExcludeAddress(address account) external onlyOwner {
        _isExcluded[account] = true;
        emit EventExcludeAddress(account);
    }

    function removeExcludedAddress(address account) external onlyOwner {
        delete _isExcluded[account];
        emit EventRemoveExcludeAddress(account);
    }

    function setBPAddrss(address _bp) external onlyOwner {
        BP = BPContract(_bp);
    }

    function setBpEnabled(bool _enabled) external onlyOwner {
        bpEnabled = _enabled;
    }

    function setDevWallet(address _devAddress) external onlyOwner {
        _dev = _devAddress;
    }

    function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
        return ((a + m - 1) / m) * m;
    }
}
