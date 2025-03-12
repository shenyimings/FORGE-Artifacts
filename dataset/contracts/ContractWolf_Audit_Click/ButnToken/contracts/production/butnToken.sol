// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPancakeFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IPancakeRouter {
    function WETH() external pure returns (address);

    function factory() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IProtection {
    function protection_beforeTokenTransfer(address from, address to, uint256 amount) external;
    function isBlacklisted(address user) external view returns (bool);
    function isEnabled() external view returns (bool);
    function enableProtection() external;
}

contract ButnToken is ERC20, ReentrancyGuard, Ownable {
    using Address for address;

    IPancakeRouter public router;

    address public pairAddress;
    address public protection;
    address public nft;

    address payable public devs;
    address payable public marketing;
    address payable public rewardsVault;

    uint8 public sellDevsFee;
    uint8 public sellMarketingFee;
    uint8 public sellRewardFee;

    uint8 public buyDevsFee;
    uint8 public buyMarketingFee;
    uint8 public buyRewardFee;

    uint256 public swapAtAmount;
    bool public isTransferEnabled;
    bool public swapAndTreasureEnabled;
    bool private _inSwapAndLiquify;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWhitelisted;

    event SwapAndTreasureEnabled(bool state);
    event SwapAtUpdated(uint256 swapAtAmount);
    event TransferEnabled(uint256 time);

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor(address _routerAddr) ERC20("Button Token", "$BUTN") Ownable(_msgSender()) {
        _mint(_msgSender(), 100_000_000_000 * 10**18); //100 000 000 000
        isExcludedFromFee[_msgSender()] = true;

        router = IPancakeRouter(_routerAddr);

        pairAddress = IPancakeFactory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        setSellTax(0, 0, 0);
        setBuyTax(0, 0, 0);

        swapAtAmount = totalSupply() / 10000; // 0.01%

        isExcludedFromFee[address(this)] = true;
        isWhitelisted[owner()] = true;
    }

    // **********************************************************************
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual{
        if (!isTransferEnabled && from != address(0) && to != nft && to != owner()) {
            require(isWhitelisted[from], "user not whitelisted");
        }
        if (protection !=  address(0)) {
            IProtection(protection).protection_beforeTokenTransfer(from, to, amount);
        }
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        _beforeTokenTransfer(from, to, amount);
        bool takeFee = true;
        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            takeFee = false;
        }
        if (from == pairAddress && takeFee) {
            uint256 dexTaxFee = buyDevsFee + buyMarketingFee + buyRewardFee;
            if (dexTaxFee > 0) {
                uint256 taxFee = (amount * dexTaxFee) / 100;
                amount = amount - taxFee;

                super._update(from, address(this), taxFee);
            }
        }

        if (to == pairAddress && takeFee) {
            uint256 dexTaxFee = sellDevsFee + sellMarketingFee + sellRewardFee;
            if (dexTaxFee > 0) {
                uint256 taxFee = (amount * dexTaxFee) / 100;
                amount = amount - taxFee;
                super._update(from, address(this), taxFee);
            }
        }

        if (
            swapAndTreasureEnabled
            && balanceOf(address(this)) >= swapAtAmount
            && !_inSwapAndLiquify
            && to == pairAddress
            && !isExcludedFromFee[from]
        ) { 
            _swapAndSendTreasure(swapAtAmount);
        }
        super._update(from, to, amount);
    }

    function _swapAndSendTreasure(uint256 _amount) internal lockTheSwap {
        uint256 contractBalance = address(this).balance;
        uint256 dexTaxFee = sellDevsFee + sellMarketingFee + sellRewardFee;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), _amount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(_amount, 0, path, address(this), block.timestamp);

        uint256 amount = address(this).balance -  contractBalance;
        if (dexTaxFee > 0){
            uint256 amountDevs = (amount * sellDevsFee) / dexTaxFee;
            if (amountDevs > 0) {
                Address.sendValue(devs, amountDevs);
            }
            
            uint256 amountMarketing = (amount * sellMarketingFee) / dexTaxFee;
            if (amountMarketing > 0) {
                Address.sendValue(marketing, amountMarketing);
            }
            
            uint256 amountReward = (amount * sellRewardFee) / dexTaxFee;
            if (amountReward > 0) {
                Address.sendValue(rewardsVault, amountReward);
            }
        }
                
    }

    function revokeBlocked(address[] calldata users, address revokeTo) external onlyOwner {
        for (uint i=0; i < users.length; i++) {
            require(IProtection(protection).isBlacklisted(users[i]), "user not blacklisted");
            require(IProtection(protection).isEnabled(), "protection disabled");

            _transfer(users[i], revokeTo, balanceOf(users[i]));
        }
    }

    function setSwapAndTreasureEnabled(bool _state) external onlyOwner {
        swapAndTreasureEnabled = _state;

        emit SwapAndTreasureEnabled(_state);
    }

    function setSwapAtAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "zero input");
        swapAtAmount = _amount;

        emit SwapAtUpdated(_amount);
    }

    function enableTransfer(address _protection) external onlyOwner {
        require(!isTransferEnabled, "transfer enabled");
        if(_protection != address(0)) {
            IProtection(_protection).enableProtection();
            protection = _protection;
        }
        isTransferEnabled = true;
        emit TransferEnabled(block.timestamp);
    }

    function setBuyTax(
        uint8 _devsFee,
        uint8 _marketingFee,
        uint8 _rewardFee
    ) public onlyOwner {
        require(_devsFee + _marketingFee + _rewardFee < 26, "fee exceed 25%");
        buyDevsFee = _devsFee;
        buyMarketingFee = _marketingFee;
        buyRewardFee = _rewardFee;
    }

    function setSellTax(
        uint8 _devsFee,
        uint8 _marketingFee,
        uint8 _rewardFee
    ) public onlyOwner {
        require(_devsFee + _marketingFee + _rewardFee < 26, "fee exceed 25%");
        sellDevsFee = _devsFee;
        sellMarketingFee = _marketingFee;
        sellRewardFee = _rewardFee;
    }

    function setRoyaltyAddresses(
        address _devs,
        address _marketing,
        address _rewardVault
    ) public onlyOwner {
        devs = payable(_devs);
        marketing = payable(_marketing);
        rewardsVault = payable(_rewardVault);
    }

    function setNft(address _nft) external onlyOwner {
        nft = _nft;
    }

    function excludeFromFee(address account, bool status) external onlyOwner {
        isExcludedFromFee[account] = status;
    }

    function addToWhitelist(address[] memory users, bool state) external onlyOwner {
        for (uint i = 0; i < users.length; i++) {
            isWhitelisted[users[i]] = state;
        }
    }

    function withdrawETH() external onlyOwner {
        Address.sendValue(payable(msg.sender), address(this).balance);
    }

    receive() external payable {}

    function withdrawERC20(address tokenAddress) external onlyOwner {
        uint256 amount = IERC20(tokenAddress).balanceOf(address(this));
        require(amount > 0, "no tokens on contract");
        IERC20(tokenAddress).transfer(_msgSender(), amount);
    }
}
