// @SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './BEP20.sol';

abstract contract AutoWithdrawFarm is BEP20 {
    uint256 private constant DISTRIBUTION = type(uint64).max;
    uint256 private constant MIN_WITHDRAWAL = 1_000_000 gwei;

    struct Holder {
        uint256 pendingWithdrawal;
        uint256 lastReflected;
        uint256 minWithdrawal;
        uint256 withdrawn;
        uint256 position;
        bool paused;
    }

    mapping(address => bool) internal _nonReflectable;
    mapping(address => bool) internal _nonTaxableSend;
    mapping(address => bool) internal _nonTaxableReceipt;
    uint8 private immutable _taxPercentage;
    uint256 private _lastProcessedIndex;
    address[] private _holderPositions;
    uint256 private _pendingReflection;
    uint256 private _maxGas = 300_000;
    uint256 private _excludedSupply;

    mapping(address => Holder) public holders;
    address public pendingManager;
    uint256 public totalWithdrawn;
    uint256 public reflected;
    address public manager;

    constructor(uint8 taxPercentage) {
        _taxPercentage = taxPercentage;
        manager = msg.sender;
    }

    function setTaxable(
        address account,
        bool taxSend,
        bool taxReceipt
    ) public onlyManager {
        _nonTaxableSend[account] = !taxSend;
        _nonTaxableReceipt[account] = !taxReceipt;

        emit SetTaxable(account, taxSend, taxReceipt);
    }

    function setReflectable(address account, bool reflectable)
        public
        onlyManager
    {
        if (reflectable && _nonReflectable[account]) {
            _excludedSupply -= _balances[account];
        } else if (!reflectable && !_nonReflectable[account]) {
            _excludedSupply += _balances[account];
        }

        _nonReflectable[account] = !reflectable;
        emit SetReflectable(account, reflectable);
    }

    function setMaxGas(uint256 maxGas) external onlyManager {
        require(
            maxGas >= 200000 && maxGas <= 500000,
            'Wagyu: maxGas must be between 200,000 and 500,000'
        );
        require(_maxGas != maxGas, 'Wagyu: same gas');
        _maxGas = maxGas;

        emit SetMaxGas(maxGas);
    }

    function transferManager(address account) external onlyManager {
        require(account != manager, 'Wagyu: already manager');

        pendingManager = account;

        emit TransferManager(account);
    }

    function acceptManager() external {
        require(msg.sender == pendingManager, 'Wagyu: not pending manager');

        manager = pendingManager;
        pendingManager = address(0);

        emit AcceptedManager(msg.sender);
    }

    function setMinWithdrawal(uint256 minWithdrawal) external {
        Holder storage holder = holders[msg.sender];
        require(
            holder.minWithdrawal != minWithdrawal,
            'Wagyu: already min withdrawal'
        );

        holder.minWithdrawal = minWithdrawal;

        emit SetMinWithdrawal(msg.sender, minWithdrawal);
    }

    function setWithdrawalsPaused(bool paused) external {
        Holder storage holder = holders[msg.sender];
        require(holder.paused != paused, 'Wagyu: same paused value');

        holder.paused = paused;

        emit SetWithdrawalsPaused(msg.sender, paused);
    }

    function withdraw() external {
        require(
            _withdraw(msg.sender, true),
            'Wagyu: cannot withdraw less than 0.001'
        );
    }

    function reflect() external payable {
        _reflect(msg.value);
    }

    function dividendsOf(address account) public view returns (uint256) {
        if (_nonReflectable[account] || reflected == 0) {
            return 0;
        }

        Holder memory holder = holders[account];

        // Get reflection position of account since last transfer
        uint256 _reflected = reflected - holder.lastReflected;
        uint256 position = (_reflected * _balances[account]) / DISTRIBUTION;

        // Return current position + past positions that have been set to pending
        return position + holder.pendingWithdrawal;
    }

    function _distributeTax(uint256 amount) internal virtual;

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), 'BEP20: transfer from the zero address');
        require(recipient != address(0), 'BEP20: transfer to the zero address');
        require(
            balanceOf(sender) >= amount,
            'BEP20: transfer amount exceeds balance'
        );

        if (_balances[sender] - amount == 0) {
            uint256 position = holders[sender].position;
            uint256 lastPosition = _holderPositions.length - 1;
            _holderPositions[position] = _holderPositions[lastPosition];
            delete _holderPositions[lastPosition];
        }

        if (_balances[recipient] == 0) {
            _holderPositions.push(recipient);
            holders[recipient].position = _holderPositions.length - 1;
        }

        uint256 taxed = _taxTransaction(sender, recipient, amount);
        _updateReflections(sender, recipient, amount, taxed);

        _balances[sender] -= amount;
        _balances[recipient] += taxed;

        emit Transfer(sender, recipient, amount);

        _processWithdrawals();
    }

    function _reflect(uint256 amount) internal {
        uint256 supply = _reflectableSupply();
        // Add reflection to pending if nobody is holding
        // or add pending to amount if there is any
        if (supply == 0) {
            _pendingReflection += amount;
            return;
        } else if (_pendingReflection > 0) {
            amount += _pendingReflection;
            _pendingReflection = 0;
        }

        reflected += (amount * DISTRIBUTION) / supply;

        emit Reflect(amount);
    }

    function _updateReflections(
        address senderAddr,
        address recipientAddr,
        uint256 amount,
        uint256 taxed
    ) internal {
        // Update excluded supply if sender or recipient isn't reflectable
        if (_nonReflectable[senderAddr]) {
            _excludedSupply -= amount;
        }
        if (_nonReflectable[recipientAddr]) {
            _excludedSupply += taxed;
        }

        Holder storage sender = holders[senderAddr];
        Holder storage recipient = holders[recipientAddr];
        if (recipient.lastReflected == 0 && _balances[recipientAddr] == 0) {
            recipient.lastReflected = reflected;
        }

        _updateReflection(sender, senderAddr);
        _updateReflection(recipient, recipientAddr);
    }

    function _updateReflection(Holder storage holder, address addr) internal {
        uint256 reflectBalance = dividendsOf(addr) - holder.pendingWithdrawal;

        holder.lastReflected = reflected;
        holder.pendingWithdrawal += reflectBalance;
    }

    function _processWithdrawals() internal {
        uint256 gasState = gasleft();
        uint256 withdrawals;
        uint256 iterations;
        uint256 gasUsed;
        for (
            uint256 gas = _maxGas > gasState ? gasState : _maxGas;
            gasUsed < gas && iterations < _holderPositions.length;
            iterations++
        ) {
            if (_lastProcessedIndex >= _holderPositions.length) {
                _lastProcessedIndex = 0;
            }

            address account = _holderPositions[_lastProcessedIndex];
            if (_withdraw(account, false)) {
                withdrawals++;
            }

            _lastProcessedIndex++;

            uint256 updatedGas = gasleft();
            if (updatedGas < gasState) {
                gasUsed += gasState - updatedGas;
                gasState = updatedGas;
            }
        }

        emit WithdrawalsProcessed(iterations, withdrawals, _lastProcessedIndex);
    }

    function _withdraw(address account, bool manual) internal returns (bool) {
        Holder storage holder = holders[account];
        uint256 amount = dividendsOf(account);
        bool userCancelled = !manual &&
            (amount < holder.minWithdrawal || holder.paused);
        if (amount < MIN_WITHDRAWAL || userCancelled) {
            return false;
        }

        payable(account).transfer(amount);
        holder.lastReflected = reflected;
        holder.pendingWithdrawal = 0;
        holder.withdrawn += amount;
        totalWithdrawn += amount;

        emit WithdrawDividends(account, amount);

        return true;
    }

    function _taxTransaction(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        if (_isNonTaxable(sender, recipient)) {
            return amount;
        }

        uint256 tax = (amount * _taxPercentage) / 100;
        _distributeTax(tax);

        return amount - tax;
    }

    function _isNonTaxable(address sender, address recipient)
        internal
        view
        returns (bool)
    {
        return _nonTaxableSend[sender] || _nonTaxableReceipt[recipient];
    }

    function _reflectableSupply() internal view returns (uint256) {
        if (_excludedSupply >= _totalSupply) {
            return 0;
        }

        return _totalSupply - _excludedSupply;
    }

    modifier onlyManager() {
        require(msg.sender == manager, 'Wagyu: not manager');
        _;
    }

    event Reflect(uint256 amount);
    event SetMaxGas(uint256 maxGas);
    event TransferManager(address account);
    event AcceptedManager(address account);
    event SetReflectable(address account, bool reflectable);
    event SetTaxable(address account, bool taxSend, bool taxReceipt);
    event SetMinWithdrawal(address account, uint256 minWithdrawal);
    event SetWithdrawalsPaused(address account, bool paused);
    event WithdrawDividends(address account, uint256 amount);
    event WithdrawalsProcessed(
        uint256 iterations,
        uint256 withdrawals,
        uint256 lastProcessedIndex
    );
}
