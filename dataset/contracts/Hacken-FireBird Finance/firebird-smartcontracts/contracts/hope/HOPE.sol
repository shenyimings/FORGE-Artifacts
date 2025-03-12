// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../upgrade/ERC777OwnableUpgradeSafe.sol";

contract HOPE is ERC777OwnableUpgradeSafe {
    uint256 public cap;

    mapping(address => uint256) public minterCap;

    uint256 public burnRate;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedToFee;

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    // ...

    /* ========== EVENTS ========== */

    event MinterCapUpdate(address indexed account, uint256 cap);

    /* ========== Modifiers =============== */

    modifier onlyMinter() {
        require(minterCap[msg.sender] > 0, "!minter");
        _;
    }

    /* ========== GOVERNANCE ========== */

    // - Max Supply: 500,000,000
    function initialize(uint256 _cap) public initializer {
        __ERC777_init("Firebird.Finance", "HOPE");
        cap = _cap;
        burnRate = 0; // 0%
        _mint(_msgSender(), 10 ether, "", ""); // pre mint 10 HOPE for initial liquidity supply purpose
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedToFee[_msgSender()] = true;
    }

    function setMinterCap(address _account, uint256 _minterCap) external onlyOwner {
        require(_account != address(0), "zero");
        minterCap[_account] = _minterCap;
        emit MinterCapUpdate(_account, _minterCap);
    }

    function setCap(uint256 _cap) external onlyOwner {
        require(_cap >= totalSupply(), "_cap is below current total supply");
        cap = _cap;
    }

    function setBurnRate(uint256 _burnRate) external onlyOwner {
        require(_burnRate <= 1000, "too high"); // <= 10%
        burnRate = _burnRate;
    }

    function setExcludeFromFee(address _account, bool _status) external onlyOwner {
        _isExcludedFromFee[_account] = _status;
    }

    function setExcludeToFee(address _account, bool _status) external onlyOwner {
        _isExcludedToFee[_account] = _status;
    }

    function setExcludeBothDirectionsFee(address _account, bool _status) external onlyOwner {
        _isExcludedFromFee[_account] = _status;
        _isExcludedToFee[_account] = _status;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function isExcludedFromFee(address _account) external view returns (bool) {
        return _isExcludedFromFee[_account];
    }

    function isExcludedToFee(address _account) external view returns (bool) {
        return _isExcludedToFee[_account];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function mint(address _recipient, uint256 _amount) public onlyMinter {
        minterCap[_msgSender()] = minterCap[_msgSender()].sub(_amount, "HOPE: minting amount exceeds minter cap");
        _mint(_recipient, _amount, "", "");
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount, "", "");
    }

    function burnFrom(address _account, uint256 _amount) external {
        _approve(_account, _msgSender(), allowance(_account, _msgSender()).sub(_amount, "HOPE: burn amount exceeds allowance"));
        _burn(_account, _amount, "", "");
    }

    /* ========== OVERRIDE STANDARD FUNCTIONS ========== */

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(recipient != address(0), "HOPE: transfer to the zero address");

        address from = _msgSender();

        _callTokensToSend(from, from, recipient, amount, "", "");

        uint256 _amountSent = _move(from, from, recipient, amount, "", "");

        _callTokensReceived(from, from, recipient, _amountSent, "", "", false);

        return true;
    }

    function transferFrom(address holder, address recipient, uint256 amount) public override returns (bool) {
        require(recipient != address(0), "HOPE: transfer to the zero address");
        require(holder != address(0), "HOPE: transfer from the zero address");

        address spender = _msgSender();

        _callTokensToSend(spender, holder, recipient, amount, "", "");

        uint256 _amountSent = _move(spender, holder, recipient, amount, "", "");
        _approve(holder, spender, allowance(holder, spender).sub(amount, "HOPE: transfer amount exceeds allowance"));

        _callTokensReceived(spender, holder, recipient, _amountSent, "", "", false);

        return true;
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(address _operator, address _from, address _to, uint256 _amount) internal override {
        super._beforeTokenTransfer(_operator, _from, _to, _amount);
        if (_from == address(0)) {
            // When minting tokens
            require(totalSupply().add(_amount) <= cap, "cap exceeded");
        }
        if (_to == address(0)) {
            // When burning tokens
            cap = cap.sub(_amount, "burn amount exceeds cap");
        }
    }

    /**
     * @dev Send tokens
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _send(address from, address to, uint256 amount, bytes memory userData, bytes memory operatorData, bool requireReceptionAck) internal override {
        require(from != address(0), "HOPE: send from the zero address");
        require(to != address(0), "HOPE: send to the zero address");

        address _operator = _msgSender();

        _callTokensToSend(_operator, from, to, amount, userData, operatorData);

        uint256 _amountSent = _move(_operator, from, to, amount, userData, operatorData);

        _callTokensReceived(_operator, from, to, _amountSent, userData, operatorData, requireReceptionAck);
    }

    function _move(address _operator, address from, address to, uint256 amount, bytes memory userData, bytes memory operatorData) internal override returns (uint256 _amountSent) {
        _beforeTokenTransfer(_operator, from, to, amount);

        uint256 _amount = amount;

        if (!_isExcludedFromFee[from] && !_isExcludedToFee[to]) {
            uint256 _burnAmount = 0;
            uint256 _burnRate = burnRate;
            if (_burnRate > 0) {
                _burnAmount = amount.mul(_burnRate).div(10000);
                _amount = _amount.sub(_burnAmount);
                _burn(from, _burnAmount, "", "");
            }
        }

        _balances[from] = _balances[from].sub(_amount, "HOPE: transfer amount exceeds balance");
        _balances[to] = _balances[to].add(_amount);
        _amountSent = _amount;

        emit Sent(_operator, from, to, _amount, userData, operatorData);
        emit Transfer(from, to, _amount);
    }

    /* ========== EMERGENCY ========== */

    function governanceRecoverUnsupported(address _token, uint256 _amount, address _to) external onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }
}
