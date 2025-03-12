// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import './interfaces/IStrategy.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'hardhat/console.sol';

contract TortleVault is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public strategy;

    uint256 public depositFee;
    uint256 public constant PERCENT_DIVISOR = 10000;
    uint256 public tvlCap;

    bool public initialized = false;
    uint256 public constructionTime;

    IERC20 public token;

    mapping(address => uint256) public cumulativeDeposits;
    mapping(address => uint256) public cumulativeWithdrawals;

    event TvlCapUpdated(uint256 newTvlCap);

    event DepositsIncremented(address user, uint256 amount, uint256 total);
    event WithdrawalsIncremented(address user, uint256 amount, uint256 total);

    constructor(
        address _token,
        string memory _name,
        string memory _symbol,
        uint256 _depositFee,
        uint256 _tvlCap
    ) ERC20(string(_name), string(_symbol)) {
        token = IERC20(_token);
        constructionTime = block.timestamp;
        depositFee = _depositFee;
        tvlCap = _tvlCap;
    }

    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(token), '!token');

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    function depositAll() external {
        deposit(token.balanceOf(msg.sender));
    }

    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    function removeTvlCap() external onlyOwner {
        updateTvlCap(type(uint256).max);
    }

    function initialize(address _strategy) public onlyOwner returns (bool) {
        require(!initialized, 'Contract is already initialized.');
        require(block.timestamp <= (constructionTime + 1200), 'initialization period over');
        strategy = _strategy;
        initialized = true;
        return true;
    }

    function balance() public view returns (uint256) {
        return token.balanceOf(address(this)) + IStrategy(strategy).balanceOf();
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : (balance() * 1e18) / totalSupply();
    }

    function deposit(uint256 _amount) public nonReentrant returns (uint256 shares) {
        uint256 vaultBalStart = token.balanceOf(address(this));
        require(_amount != 0, 'please provide amount');
        uint256 _pool = vaultBalStart + IStrategy(strategy).balanceOf();
        require(_pool + _amount <= tvlCap, 'vault is full!');

        token.safeTransferFrom(msg.sender, address(this), _amount);
        _amount = token.balanceOf(address(this)) - vaultBalStart;
        uint256 _amountAfterDeposit = (_amount * (PERCENT_DIVISOR - depositFee)) / PERCENT_DIVISOR;
        shares = _amountAfterDeposit;
        if (totalSupply() != 0) {
            shares = (_amountAfterDeposit * totalSupply()) / _pool;
        }
        _mint(msg.sender, shares);
        earn();
        incrementDeposits(_amount);
    }

    function earn() public {
        token.safeTransfer(strategy, token.balanceOf(address(this)));
        IStrategy(strategy).deposit();
    }

    function withdraw(uint256 _shares) public nonReentrant returns (uint256 r) {
        require(_shares > 0, 'please provide amount');
        uint256 tokenBalStart = token.balanceOf(address(this));
        r = ((IStrategy(strategy).balanceOf() + tokenBalStart) * _shares) / totalSupply();
        _burn(msg.sender, _shares);
        if (tokenBalStart < r) {
            uint256 _withdraw = r - tokenBalStart;
            IStrategy(strategy).withdraw(_withdraw);
            uint256 _diff = token.balanceOf(address(this)) - tokenBalStart;
            if (_diff < _withdraw) {
                r = tokenBalStart + _diff;
            }
        }
        token.safeTransfer(msg.sender, r);
        incrementWithdrawals(r);
    }

    function updateDepositFee(uint256 fee) public onlyOwner {
        depositFee = fee;
    }

    function updateTvlCap(uint256 _newTvlCap) public onlyOwner {
        tvlCap = _newTvlCap;
        emit TvlCapUpdated(tvlCap);
    }

    function incrementDeposits(uint256 _amount) internal returns (bool) {
        uint256 newTotal = cumulativeDeposits[tx.origin] + _amount;
        cumulativeDeposits[tx.origin] = newTotal;
        emit DepositsIncremented(tx.origin, _amount, newTotal);
        return true;
    }

    function incrementWithdrawals(uint256 _amount) internal returns (bool) {
        uint256 newTotal = cumulativeWithdrawals[tx.origin] + _amount;
        cumulativeWithdrawals[tx.origin] = newTotal;
        emit WithdrawalsIncremented(tx.origin, _amount, newTotal);
        return true;
    }
}
