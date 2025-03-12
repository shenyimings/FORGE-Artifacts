// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../StratBase.sol";
import "../../Interfaces/Diffusion/IMiniChef.sol";
import "../../Interfaces/Uniswap/IUniswapV2Pair.sol";
import "../../Interfaces/Uniswap/IUniswapV2Router.sol";

contract StratDiffusion is StratBase, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMathUpgradeable for uint256;

    IMiniChef public constant miniChef =
        IMiniChef(0x067eC87844fBD73eDa4a1059F30039584586e09d);

    IERC20 public constant diff =
        IERC20(0x3f75ceabCDfed1aCa03257Dc6Bdc0408E2b4b026);

    IUniswapV2Router public constant uniRouter =
        IUniswapV2Router(0xFCd2Ce20ef8ed3D43Ab4f8C2dA13bbF1C6d9512F);

    uint256 pid;

    bool public harvestOnDeposit;

    uint256 public constant FEE_PRECISION = 1e6;
    uint256 public harvestFeeRate;
    uint256 public withdrawalFeeRate;

    IERC20 public lpToken0;
    IERC20 public lpToken1;

    // path
    address[] public diffToLpToken0;
    address[] public diffToLpToken1;

    event PidUpdated(uint256 _pid);
    event Deposited(uint256 _amount);
    event Withdrawn(uint256 _amount, uint256 _withdrawalFee);
    event Harvested(uint256 _amount, uint256 _harvestFee);
    event HarvestFeeRateUpdated(uint256 _feeRate);
    event WithdrawalFeeRateUpdated(uint256 _feeRate);

    function initialize() public initializer {
        __StratBase_init();

        __Pausable_init_unchained();
    }

    function setParams(
        address _vault,
        address _want,
        address _keeper,
        address _feeRecipient,
        uint256 _pid
    ) external onlyOwner {
        setAddresses(_vault, _want, _keeper, _feeRecipient);

        require(_want == miniChef.lpToken(_pid), "invalid _want or _pid");
        pid = _pid;

        lpToken0 = IERC20(IUniswapV2Pair(_want).token0());
        lpToken1 = IERC20(IUniswapV2Pair(_want).token1());

        if (lpToken0 != diff) {
            diffToLpToken0 = [address(diff), address(lpToken0)];
        }

        if (lpToken1 != diff) {
            diffToLpToken1 = [address(diff), address(lpToken1)];
        }

        _giveAllowances();

        harvestOnDeposit = true;

        emit PidUpdated(_pid);
    }

    function beforeDeposit() external override onlyVault {
        if (!harvestOnDeposit) {
            return;
        }
        harvest();
    }

    function deposit() public override whenNotPaused {
        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal > 0) {
            miniChef.deposit(pid, wantBal, address(this));

            emit Deposited(wantBal);
        }
    }

    function withdraw(uint256 _amount) external override onlyVault {
        uint256 wantBal = want.balanceOf(address(this));

        if (wantBal < _amount) {
            miniChef.withdraw(pid, _amount.sub(wantBal), address(this));
            wantBal = want.balanceOf(address(this));
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        uint256 withdrawalFee = wantBal.mul(withdrawalFeeRate).div(
            FEE_PRECISION
        );
        want.safeTransfer(feeRecipient, withdrawalFee);
        want.safeTransfer(vault, wantBal.sub(withdrawalFee));

        emit Withdrawn(_amount, withdrawalFee);
    }

    // calculate the total underlying 'want' held by the strat.
    function balanceOf() external view override returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view override returns (uint256) {
        return want.balanceOf(address(this));
    }

    // it calculates how much 'want' the strategy has working in the farm.
    function balanceOfPool() public view override returns (uint256) {
        (uint256 _amount, ) = miniChef.userInfo(pid, address(this));
        return _amount;
    }

    // compounds earnings
    function harvest() public override whenNotPaused {
        if (balanceOfPool() > 0) {
            // claim diff
            miniChef.harvest(pid, address(this));

            uint256 diffBal = diff.balanceOf(address(this));
            if (diffBal > 0) {
                // charge fees
                uint256 harvestFee = diffBal.mul(harvestFeeRate).div(
                    FEE_PRECISION
                );
                diff.safeTransfer(feeRecipient, harvestFee);

                // swap diff
                uint256 diffBalHalf = diffBal.sub(harvestFee).div(2);
                if (lpToken0 != diff) {
                    uniRouter.swapExactTokensForTokens(
                        diffBalHalf,
                        0,
                        diffToLpToken0,
                        address(this),
                        now
                    );
                }
                if (lpToken1 != diff) {
                    uniRouter.swapExactTokensForTokens(
                        diffBalHalf,
                        0,
                        diffToLpToken1,
                        address(this),
                        now
                    );
                }

                // Adds liquidity and gets more want tokens.
                uniRouter.addLiquidity(
                    address(lpToken0),
                    address(lpToken1),
                    lpToken0.balanceOf(address(this)),
                    lpToken1.balanceOf(address(this)),
                    1,
                    1,
                    address(this),
                    now
                );

                // reinvest
                deposit();

                emit Harvested(diffBal, harvestFee);
            }
        }
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external override onlyVault {
        miniChef.emergencyWithdraw(pid, address(this));

        uint256 wantBal = want.balanceOf(address(this));
        want.safeTransfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        pause();
        miniChef.emergencyWithdraw(pid, address(this));
    }

    function pause() public onlyManager {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function _giveAllowances() internal {
        want.safeApprove(address(miniChef), uint256(-1));
        diff.safeApprove(address(uniRouter), uint256(-1));
        if (lpToken0 != diff) {
            lpToken0.safeApprove(address(uniRouter), uint256(-1));
        }
        if (lpToken1 != diff) {
            lpToken1.safeApprove(address(uniRouter), uint256(-1));
        }
    }

    function _removeAllowances() internal {
        want.safeApprove(address(miniChef), 0);
        diff.safeApprove(address(uniRouter), 0);
        if (lpToken0 != diff) {
            lpToken0.safeApprove(address(uniRouter), 0);
        }
        if (lpToken1 != diff) {
            lpToken1.safeApprove(address(uniRouter), 0);
        }
    }

    function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyManager {
        harvestOnDeposit = _harvestOnDeposit;
    }

    function setHarvestFeeRate(uint256 _feeRate) external onlyManager {
        require(_feeRate <= FEE_PRECISION.mul(30).div(100), "!cap");

        harvestFeeRate = _feeRate;
        emit HarvestFeeRateUpdated(_feeRate);
    }

    function setWithdrawalFeeRate(uint256 _feeRate) external onlyManager {
        require(_feeRate <= FEE_PRECISION.mul(5).div(100), "!cap");

        withdrawalFeeRate = _feeRate;
        emit WithdrawalFeeRateUpdated(_feeRate);
    }

    function setLpToken0Path(address[] memory _diffToLpToken0)
        external
        onlyManager
    {
        diffToLpToken0 = _diffToLpToken0;
    }

    function setLpToken1Path(address[] memory _diffToLpToken1)
        external
        onlyManager
    {
        diffToLpToken1 = _diffToLpToken1;
    }
}
