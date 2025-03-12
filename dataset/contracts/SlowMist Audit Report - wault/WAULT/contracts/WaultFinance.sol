// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract WaultFinance is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private rewardsBalance;
    mapping(address => uint256) private actualBalance;
    mapping(address => mapping(address => uint256)) private allowances;

    mapping(address => bool) private isExcludedFromFees;
    mapping(address => bool) private isExcludedFromRewards;
    address[] private excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant TOTAL_SUPPLY = 1000000 ether;
    uint256 private rewardsTotal = (MAX - (MAX % TOTAL_SUPPLY));
    
    string public constant name = "Wault Finance";
    string public constant symbol = "WAULT";
    uint8 public constant decimals = 18;

    uint256 public totalTaxPermille = 30;
    uint256 public liquidityMiningTaxPermille = 12;
    uint256 public stakingTaxPermille = 5;
    uint256 public holdersTaxPermille = 8;
    uint256 public marketingTaxPermille = 5;

    address public liquidityMiningAddress;
    address public stakingAddress;
    address public marketingAddress;

    constructor(address _liquidityMiningAddress, address _stakingAddress, address _marketingAddress, address _factoryAddress, address _weth) {
        liquidityMiningAddress = _liquidityMiningAddress;
        stakingAddress = _stakingAddress;
        marketingAddress = _marketingAddress;
        
        rewardsBalance[_msgSender()] = rewardsTotal;
        emit Transfer(address(0), _msgSender(), TOTAL_SUPPLY);
        
        excludeFromFees(liquidityMiningAddress);
        excludeFromRewards(liquidityMiningAddress);
        excludeFromFees(stakingAddress);
        excludeFromRewards(stakingAddress);
        excludeFromFees(marketingAddress);
        excludeFromRewards(marketingAddress);
        excludeFromFees(_msgSender());
        excludeFromRewards(_msgSender());
        
        transfer(liquidityMiningAddress, 400000 ether);
        transfer(stakingAddress, 100000 ether);
        transfer(marketingAddress, 40000 ether);
        
        address pairAddress = IFactory(_factoryAddress).createPair(_weth, address(this));
        excludeFromRewards(pairAddress);
    }

    function totalSupply() external pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (isExcludedFromRewards[account]) {
            return actualBalance[account];
        }
        return calculateRewards(rewardsBalance[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function excludeFromFees(address account) public onlyOwner() {
        require(!isExcludedFromFees[account], "Account is already excluded from fees");
        isExcludedFromFees[account] = true;
    }

    function includeInFees(address account) public onlyOwner() {
        require(isExcludedFromFees[account], "Account is already included in fees");
        isExcludedFromFees[account] = false;
    }

    function excludeFromRewards(address account) public onlyOwner() {
        require(!isExcludedFromRewards[account], "Account is already excluded from rewards");
        if (rewardsBalance[account] > 0) {
            actualBalance[account] = calculateRewards(rewardsBalance[account]);
        }

        isExcludedFromRewards[account] = true;
        excluded.push(account);
    }

    function includeInRewards(address account) public onlyOwner() {
        require(isExcludedFromRewards[account], "Account is already included in rewards");

        for (uint256 i = 0; i < excluded.length; i++) {
            if (excluded[i] == account) {
                excluded[i] = excluded[excluded.length - 1];
                actualBalance[account] = 0;
                isExcludedFromRewards[account] = false;
                excluded.pop();
                break;
            }
        }
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 _totalTaxPermille = totalTaxPermille;
        if (isExcludedFromFees[sender] || isExcludedFromFees[recipient]) {
            totalTaxPermille = 0;
        } else {
            uint256 liquidityMiningFee = amount.mul(liquidityMiningTaxPermille).div(1000);
            uint256 stakingFee = amount.mul(stakingTaxPermille).div(1000);
            uint256 marketingFee = amount.mul(marketingTaxPermille).div(1000);
            actualBalance[liquidityMiningAddress] = actualBalance[liquidityMiningAddress].add(liquidityMiningFee);
            actualBalance[stakingAddress] = actualBalance[stakingAddress].add(stakingFee);
            actualBalance[marketingAddress] = actualBalance[marketingAddress].add(marketingFee);
        }

        if (isExcludedFromRewards[sender] && !isExcludedFromRewards[recipient]) {
            transferWithoutSenderRewards(sender, recipient, amount);
        } else if (!isExcludedFromRewards[sender] && isExcludedFromRewards[recipient]) {
            transferWithRecipientRewards(sender, recipient, amount);
        } else if (!isExcludedFromRewards[sender] && !isExcludedFromRewards[recipient]) {
            transferWithRewards(sender, recipient, amount);
        } else if (isExcludedFromRewards[sender] && isExcludedFromRewards[recipient]) {
            transferWithoutRewards(sender, recipient, amount);
        } else {
            transferWithRewards(sender, recipient, amount);
        }

        if (_totalTaxPermille != totalTaxPermille) {
            totalTaxPermille = _totalTaxPermille;
        }
    }

    function transferWithRewards(address sender, address recipient, uint256 actualAmount) private {
        (uint256 rewardAmount, uint256 rewardTransferAmount, uint256 rewardFee, uint256 actualTransferAmount, ) = getValues(actualAmount);

        rewardsBalance[sender] = rewardsBalance[sender].sub(rewardAmount);
        rewardsBalance[recipient] = rewardsBalance[recipient].add(rewardTransferAmount);
        rewardsTotal = rewardsTotal.sub(rewardFee);
        emit Transfer(sender, recipient, actualTransferAmount);
    }

    function transferWithRecipientRewards(address sender, address recipient, uint256 actualAmount) private {
        (uint256 rewardAmount, uint256 rewardTransferAmount, uint256 rewardFee, uint256 actualTransferAmount, ) = getValues(actualAmount);

        rewardsBalance[sender] = rewardsBalance[sender].sub(rewardAmount);
        actualBalance[recipient] = actualBalance[recipient].add(actualTransferAmount);
        rewardsBalance[recipient] = rewardsBalance[recipient].add(rewardTransferAmount);
        rewardsTotal = rewardsTotal.sub(rewardFee);
        emit Transfer(sender, recipient, actualTransferAmount);
    }

    function transferWithoutSenderRewards(address sender, address recipient, uint256 actualAmount) private {
        (uint256 rewardAmount, uint256 rewardTransferAmount, uint256 rewardFee, uint256 actualTransferAmount, ) = getValues(actualAmount);

        actualBalance[sender] = actualBalance[sender].sub(actualAmount);
        rewardsBalance[sender] = rewardsBalance[sender].sub(rewardAmount);
        rewardsBalance[recipient] = rewardsBalance[recipient].add(rewardTransferAmount);
        rewardsTotal = rewardsTotal.sub(rewardFee);
        emit Transfer(sender, recipient, actualTransferAmount);
    }

    function transferWithoutRewards(address sender, address recipient, uint256 actualAmount) private {
        (uint256 rewardAmount, uint256 rewardTransferAmount, uint256 rewardFee, uint256 actualTransferAmount, ) = getValues(actualAmount);

        actualBalance[sender] = actualBalance[sender].sub(actualAmount);
        rewardsBalance[sender] = rewardsBalance[sender].sub(rewardAmount);
        actualBalance[recipient] = actualBalance[recipient].add(actualTransferAmount);
        rewardsBalance[recipient] = rewardsBalance[recipient].add(rewardTransferAmount);
        rewardsTotal = rewardsTotal.sub(rewardFee);
        emit Transfer(sender, recipient, actualTransferAmount);
    }

    function calculateRewards(uint256 rewardAmount) public view returns (uint256) {
        require(rewardAmount <= rewardsTotal, "Amount must be less than total rewards");
        uint256 rewardsRate = getRewardsRate();
        return rewardAmount.div(rewardsRate);
    }

    function getValues(uint256 actualAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 actualTransferAmount, uint256 actualFee) = getActualValues(actualAmount);
        uint256 rewardsRate = getRewardsRate();
        (uint256 rewardAmount, uint256 rewardTransferAmount, uint256 rewardFee) = getRewardValues(actualAmount, actualFee, rewardsRate);

        return (rewardAmount, rewardTransferAmount, rewardFee, actualTransferAmount, actualFee);
    }

    function getActualValues(uint256 actualAmount) private view returns (uint256, uint256) {
        uint256 actualFee = actualAmount.mul(totalTaxPermille).div(1000);
        uint256 actualHolderFee = actualAmount.mul(holdersTaxPermille).div(1000);
        uint256 actualTransferAmount = actualAmount.sub(actualFee);
        return (actualTransferAmount, actualHolderFee);
    }

    function getRewardValues(uint256 actualAmount, uint256 actualHolderFee, uint256 rewardsRate) private view returns (uint256, uint256, uint256)
    {
        uint256 actualFee = actualAmount.mul(totalTaxPermille).div(1000).mul(rewardsRate);
        uint256 rewardAmount = actualAmount.mul(rewardsRate);
        uint256 rewardTransferAmount = rewardAmount.sub(actualFee);
        uint256 rewardFee = actualHolderFee.mul(rewardsRate);
        return (rewardAmount, rewardTransferAmount, rewardFee);
    }

    function getRewardsRate() private view returns (uint256) {
        (uint256 rewardsSupply, uint256 actualSupply) = getCurrentSupply();
        return rewardsSupply.div(actualSupply);
    }

    function getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rewardsSupply = rewardsTotal;
        uint256 actualSupply = TOTAL_SUPPLY;

        for (uint256 i = 0; i < excluded.length; i++) {
            if (rewardsBalance[excluded[i]] > rewardsSupply || actualBalance[excluded[i]] > actualSupply) {
                return (rewardsTotal, TOTAL_SUPPLY);
            }

            rewardsSupply = rewardsSupply.sub(rewardsBalance[excluded[i]]);
            actualSupply = actualSupply.sub(actualBalance[excluded[i]]);
        }

        if (rewardsSupply < rewardsTotal.div(TOTAL_SUPPLY)) {
            return (rewardsTotal, TOTAL_SUPPLY);
        }

        return (rewardsSupply, actualSupply);
    }
}
