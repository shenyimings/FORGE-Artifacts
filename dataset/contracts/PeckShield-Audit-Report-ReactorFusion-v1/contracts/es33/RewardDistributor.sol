// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../lib/Ledger.sol";
import "../CToken.sol";
import "../CErc20.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IPair.sol";
import "../interfaces/IWETH.sol";
import "./ES33.sol";

interface IBribe {
    function notifyRewardAmount(address token, uint256 amount) external;
}

interface IGauge {
    function getReward(address account, address[] memory tokens) external;

    function rewardRate(address) external returns (uint256);

    function deposit(uint256 amount, uint256 tokenId) external;

    function stake() external returns (address);

    function balanceOf(address) external returns (uint256);

    function totalSupply() external returns (uint256);
}

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
}

contract RewardDistributor is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using LedgerLib for Ledger;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant BRIBE_ACCOUNT = bytes32("BRIBE");
    ES33 public underlying;
    address cEther;
    address weth;
    IBribe bribe;
    IGauge gauge;
    IERC20 vc;
    IRouter router;
    IComptroller comptroller;
    Ledger weights;
    mapping(bytes32 => Ledger) assetLedgers;
    mapping(address => uint256) accruedInterest;
    uint256 supposedBalance; // unused. included for historical reasons

    uint256 public lastReap;
    uint256 public lastGaugeClaim;
    uint256 public duration;
    uint256 public swappedRF;
    event Harvest(address addr, uint256 amount);

    function initialize(
        address admin,
        ES33 underlying_,
        address cEther_,
        address weth_,
        IRouter router_
    ) external initializer {
        _transferOwnership(admin);
        __ReentrancyGuard_init();
        underlying = underlying_;
        cEther = cEther_;
        weth = weth_;
        router = router_;
    }

    function stakeLP() external onlyOwner {
        address stakeToken = gauge.stake();
        uint256 balance = IERC20(stakeToken).balanceOf(address(this));
        IERC20(stakeToken).approve(address(gauge), balance);
        gauge.deposit(balance, 0);
    }

    // todo: takeLP
    function slot(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function slot(IERC20 a) internal pure returns (bytes32) {
        return slot(address(a));
    }

    function slot(
        address informationSource,
        bytes32 kind
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(informationSource, kind));
    }

    function setExternals(
        IBribe bribe_,
        IGauge gauge_,
        IERC20 vc_,
        IComptroller comptroller_
    ) external onlyOwner {
        bribe = bribe_;
        gauge = gauge_;
        vc = vc_;
        comptroller = comptroller_;
    }

    function onAssetIncrease(
        bytes32 kind,
        address account,
        uint256 delta
    ) external nonReentrant {
        bytes32[] memory a = new bytes32[](1);
        a[0] = slot(msg.sender, kind);
        _harvest(account, a);
        Ledger storage ledger = assetLedgers[slot(msg.sender, kind)];
        ledger.deposit(slot(account), delta);
    }

    function onAssetDecrease(
        bytes32 kind,
        address account,
        uint256 delta
    ) external nonReentrant {
        bytes32[] memory a = new bytes32[](1);
        a[0] = slot(msg.sender, kind);
        _harvest(account, a);
        Ledger storage ledger = assetLedgers[slot(msg.sender, kind)];
        ledger.withdraw(slot(account), delta);
    }

    function onAssetChange(
        bytes32 kind,
        address account,
        uint256 amount
    ) external nonReentrant {
        bytes32[] memory a = new bytes32[](1);
        a[0] = slot(msg.sender, kind);
        _harvest(account, a);
        Ledger storage ledger = assetLedgers[slot(msg.sender, kind)];
        ledger.withdrawAll(slot(account));
        ledger.deposit(slot(account), amount);
    }

    function _harvest(
        address addr,
        bytes32[] memory ledgerIds
    ) internal returns (uint256) {
        updateRewards(ledgerIds);
        uint256 harvested = 0;

        for (uint256 j = 0; j < ledgerIds.length; j++) {
            harvested += assetLedgers[ledgerIds[j]].harvest(
                slot(addr),
                slot(address(underlying))
            );
        }
        accruedInterest[addr] += harvested;
        return harvested;
    }

    function harvest(
        bytes32[] memory ledgerIds
    ) external nonReentrant returns (uint256) {
        _harvest(msg.sender, ledgerIds);
        uint256 amount = accruedInterest[msg.sender];
        accruedInterest[msg.sender] = 0;
        IERC20(address(underlying)).safeTransfer(msg.sender, amount);
        emit Harvest(msg.sender, amount);
        return amount;
    }

    function updateRewards(bytes32[] memory ledgerIds) public {
        uint256 delta = underlying.mintEmission();
        if (delta != 0) {
            weights.reward(slot(address(underlying)), delta);
        }

        for (uint256 j = 0; j < ledgerIds.length; j++) {
            if (ledgerIds[j] != BRIBE_ACCOUNT) {
                uint256 amount = weights.harvest(
                    ledgerIds[j],
                    slot(address(underlying))
                );
                assetLedgers[ledgerIds[j]].reward(
                    slot(address(underlying)),
                    amount
                );
            }
        }
        uint256 bribeAmount = weights.harvest(
            BRIBE_ACCOUNT,
            slot(address(underlying))
        );
        if (bribeAmount > 0) {
            underlying.approve(address(bribe), bribeAmount);
            bribe.notifyRewardAmount(address(underlying), bribeAmount);
        }
    }

    function setWeights(
        bytes32[] calldata _ids,
        uint256[] calldata _weights
    ) external onlyOwner nonReentrant {
        updateRewards(_ids);
        for (uint256 i = 0; i < _ids.length; i++) {
            weights.withdrawAll(_ids[i]);
            weights.deposit(_ids[i], _weights[i]);
        }
    }

    function borrowSlot(address cToken) external pure returns (bytes32) {
        return slot(cToken, bytes32("BORROW"));
    }

    function supplySlot(address cToken) external pure returns (bytes32) {
        return slot(cToken, bytes32("SUPPLY"));
    }

    function reset() external onlyOwner {
        lastGaugeClaim = block.timestamp - 10 minutes - 1;
        duration = 10 minutes;
    }

    function reap() public nonReentrant returns (uint256, uint256) {
        if (lastReap == block.timestamp) return (0, 0);
        require(msg.sender == address(underlying), "only underlying");
        // hardcoded to save gas
        IERC20 usdc = IERC20(0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4);
        CToken ceth = CToken(0xC5db68F30D21cBe0C9Eac7BE5eA83468d69297e6);
        CToken cusdc = CToken(0x04e9Db37d8EA0760072e1aCE3F2A219988Fdac29);
        IPair ethrf = IPair(0x62eB02CB53673b5855f2C0Ea4B8fE198901F34Ac);
        IPair usdceth = IPair(0xcD52cbc975fbB802F82A1F92112b1250b5a997Df);
        uint256 vc_delta;
        uint256 vcBal = vc.balanceOf(address(this));
        uint256 rf_delta;

        if (block.timestamp - lastGaugeClaim >= duration) {
            rf_delta += swappedRF;
            swappedRF = 0;
            ceth.takeReserves();
            cusdc.takeReserves();
            uint256 wethTotal = 0;
            uint256 usdcbal = usdc.balanceOf(address(this));
            uint256 usdcWethOut = usdceth.getAmountOut(usdcbal, address(usdc));
            if (usdcWethOut > 0) {
                usdc.transfer(address(usdceth), usdcbal);
                usdceth.swap(0, usdcWethOut, address(ethrf), "");
                wethTotal += usdcWethOut;
            }
            uint256 ethbal = address(this).balance;
            IWETH(weth).deposit{value: ethbal}();
            IWETH(weth).transfer(address(ethrf), ethbal);
            wethTotal += ethbal;
            uint256 rfOut = ethrf.getAmountOut(wethTotal, address(weth));
            if (rfOut > 0) {
                ethrf.swap(0, rfOut, address(this), "");
            }
            swappedRF = rfOut;
            address[] memory b = new address[](1);
            b[0] = address(vc);

            vc_delta += vcBal;

            gauge.getReward(address(this), b);
            vcBal = vc.balanceOf(address(this)) - vcBal;
            lastReap = lastGaugeClaim + duration;
            lastGaugeClaim = block.timestamp;

            duration = Math.min(1 days, (duration * 15) / 10);
        }
        if (lastGaugeClaim + duration > lastReap) {
            vc_delta +=
                (vcBal * (block.timestamp - lastReap)) /
                (lastGaugeClaim + duration - lastReap);
            uint256 rf_delta_new = (swappedRF * (block.timestamp - lastReap)) /
                (lastGaugeClaim + duration - lastReap);
            rf_delta += rf_delta_new;
            if (rf_delta_new <= swappedRF) {
                swappedRF -= rf_delta_new;
            } else {
                swappedRF = 0;
            }
        }
        lastReap = block.timestamp;
        if (vc_delta > 0) vc.transfer(address(underlying), vc_delta);
        if (rf_delta > 0) underlying.transfer(address(underlying), rf_delta);
        return (rf_delta, vc_delta);
    }

    receive() external payable {}

    //--- view functions

    function currentPrice(
        IERC20 qtyToken,
        IERC20 quoteToken
    ) internal view returns (uint256) {
        IPair pair = IPair(
            router.pairFor(address(qtyToken), address(quoteToken), false)
        );
        (uint256 r0, uint256 r1, ) = pair.getReserves();
        (IERC20 t0, ) = pair.tokens();
        return
            qtyToken == t0
                ? Math.mulDiv(1e18, r1, r0)
                : Math.mulDiv(1e18, r0, r1);
    }

    function rewardRateAll()
        external
        returns (
            address[] memory cts,
            uint256[] memory supplies,
            uint256[] memory borrows
        )
    {
        cts = comptroller.getAllMarkets();
        supplies = new uint256[](cts.length);
        borrows = new uint256[](cts.length);
        uint256 totalRate = underlying.emissionRate();
        for (uint256 i = 0; i < cts.length; i++) {
            supplies[i] = CToken(cts[i]).totalSupply() == 0
                ? 0
                : ((totalRate *
                    weights.shareOf(slot(cts[i], bytes32("SUPPLY")))) * 1e18) /
                    (CToken(cts[i]).totalSupply() *
                        CToken(cts[i]).exchangeRateCurrent());
            borrows[i] = (CToken(cts[i]).totalBorrowsCurrent()) == 0
                ? 0
                : (
                    (totalRate *
                        weights.shareOf(slot(cts[i], bytes32("BORROW"))))
                ) / (CToken(cts[i]).totalBorrowsCurrent());
        }
        return (cts, supplies, borrows);
    }

    function emissionRates() external returns (uint256, uint256) {
        reap();
        address[] memory cts = comptroller.getAllMarkets();
        uint256 totalES33Rate = 0;
        uint256 ethPrice = currentPrice(
            IERC20(weth),
            IERC20(address(underlying))
        );
        for (uint256 i = 0; i < cts.length; i++) {
            CErc20 ct = CErc20(cts[i]);
            uint256 totalInterests = Math.mulDiv(
                ct.totalBorrowsCurrent(),
                ct.borrowRatePerBlock(),
                1e18
            );
            uint256 tokenInflow = Math.mulDiv(
                totalInterests,
                ct.reserveFactorMantissa(),
                1e18
            );
            uint256 ethConversionRate = address(ct) == cEther
                ? 1e18
                : currentPrice(IERC20(ct.underlying()), IERC20(weth));
            uint256 ethInflow = Math.mulDiv(
                tokenInflow,
                ethConversionRate,
                1e18
            );
            totalES33Rate += Math.mulDiv(ethInflow, ethPrice, 1e18);
        }
        uint256 totalVCRate = (gauge.rewardRate(address(vc)) *
            gauge.balanceOf(address(this))) / gauge.totalSupply();

        return (totalES33Rate, totalVCRate);
    }
}
