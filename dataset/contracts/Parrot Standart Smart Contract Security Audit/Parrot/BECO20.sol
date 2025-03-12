// SPDX-License-Identifier: MIT

import "IBEP20.sol";
import "Context.sol";
import "ISwapV2.sol";
import "IBridgeEcosystem.sol";

pragma solidity ^0.8.5;

abstract contract BECO20 is Context, IBEP20 {
    mapping(address => mapping(address => uint256)) internal _allowances;
    mapping(address => uint256) internal _balances;
    mapping(address => Index) internal _excludeList;
    address[] internal _excludeListStorage;
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply;
    bool internal _inSwap;
    address[] internal sellPath;
    ISwapRouterV2 public swapRouter;
    address public immutable swapPair;
    address public constant bridgeEcosystem = 0x763f64FB6190c59d7D51061A6a9a1cee125b0753;

    event SwapAndSendBECOContributions(uint256 tokensSwapped);
    event AddedToExcludeList(address account);
    event RemovedFromExcludeList(address account);

    struct Index {
        bool contains;
        uint256 index;
    }

    modifier lockSwap {
        _inSwap = true;
        _;
        _inSwap = false;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply,
        address swapRouter_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = initialSupply;

        ISwapRouterV2 _swapRouter = ISwapRouterV2(swapRouter_);
        swapRouter = _swapRouter;
        swapPair = ISwapV2Factory(_swapRouter.factory()).createPair(
            address(this),
            _swapRouter.WETH()
        );
        sellPath = [address(this), _swapRouter.WETH()];

        _addToExcludeList(bridgeEcosystem);
        _addToExcludeList(address(this));
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "BECO20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "BECO20: transfer amount exceeds allowance"
        );
        unchecked {_approve(sender, _msgSender(), currentAllowance - amount);}

        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "BECO20: approve from the zero address");
        require(spender != address(0), "BECO20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "BECO20: transfer from the zero address");
        require(recipient != address(0), "BECO20: transfer to the zero address");
        require(amount > 0, "BECO20: amount must be greater than 0");

        bool whitelistedByBridge = IBridgeEcosystem(bridgeEcosystem).isWhitelisted(address(this));
        if (sender != swapPair && !_inSwap) {
            if(whitelistedByBridge) _checkBECOSwap();
            _checkSwap();
        }

        if (!(_isExcluded(sender) || _isExcluded(recipient))) {
            uint256 becoFee;
            if(whitelistedByBridge)
            {
                becoFee = amount / 20;
                _transferTokens(sender, bridgeEcosystem, becoFee);
            }
            _transferTokens(sender, recipient, amount - becoFee);

        } else if (sender == swapPair && recipient == bridgeEcosystem) {
            _burn(recipient, amount);
        } else {
            _transferTokens(sender, recipient, amount);
        }
    }

    function _transferTokens(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _checkSwap() internal virtual {}

    function _checkBECOSwap() private {
        uint256 becoBalance = balanceOf(bridgeEcosystem);
        uint256 swapAmount = _totalSupply / 2000;
        if (becoBalance >= swapAmount) {
            _swapAndSendBECOContributions(swapAmount);
        }
    }

    function _swapAndSendBECOContributions(uint256 swapAmount)
        private
        lockSwap
    {
        _transfer(bridgeEcosystem, address(this), swapAmount);
        _approve(address(this), address(swapRouter), swapAmount);
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0, // slippage is unavoidable
            sellPath,
            bridgeEcosystem,
            block.timestamp
        );
        emit SwapAndSendBECOContributions(swapAmount);
    }

    function _isExcluded(address account) internal view returns (bool) {
        return _excludeList[account].contains;
    }

    function _addToExcludeList(address account) internal {
        require(!_isExcluded(account), "BECO20: Account is not excluded");
        require(
            account != address(swapRouter),
            "BECO20: You can't exclude swap router"
        );

        _excludeListStorage.push(account);
        _excludeList[account].contains = true;
        _excludeList[account].index = _excludeListStorage.length - 1;

        emit AddedToExcludeList(account);
    }

    function _removeFromExcludeList(address account) internal {
        require(_isExcluded(account), "BECO20: Account is excluded");
        require(
            account == bridgeEcosystem,
            "BECO20: You can't remove bridge ecosystem"
        );
        require(account == address(this), "You can't remove contract address");
        _excludeListStorage[_excludeList[account].index] = _excludeListStorage[
            _excludeListStorage.length - 1
        ];
        _excludeListStorage.pop();
        _excludeList[account].contains = false;
        emit RemovedFromExcludeList(account);
    }
}