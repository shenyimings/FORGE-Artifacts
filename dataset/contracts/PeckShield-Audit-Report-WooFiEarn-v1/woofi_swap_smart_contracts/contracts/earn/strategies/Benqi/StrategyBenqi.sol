// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '../../../interfaces/BankerJoe/IJoeRouter.sol';
import '../../../interfaces/BankerJoe/IVToken.sol';
import '../../../interfaces/BankerJoe/IComptroller.sol';
import '../../../interfaces/IWooAccessManager.sol';
import '../../../interfaces/IWETH.sol';
import '../BaseStrategy.sol';

contract StrategyBenqi is BaseStrategy {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* ----- State Variables ----- */

    // list of benqi markets
    // qiAvax:  0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c  https://snowtrace.io/address/0x5c0401e81bc07ca70fad469b451682c0d747ef1c
    // qiBTC:   0xe194c4c5aC32a3C9ffDb358d9Bfd523a0B6d1568  https://snowtrace.io/address/0xe194c4c5ac32a3c9ffdb358d9bfd523a0b6d1568
    // qiETH:   0x334AD834Cd4481BB02d09615E7c11a00579A7909  https://snowtrace.io/address/0x334ad834cd4481bb02d09615e7c11a00579a7909
    // qiUSDT:  0xc9e5999b8e75C3fEB117F6f73E664b9f3C8ca65C  https://snowtrace.io/address/0xc9e5999b8e75c3feb117f6f73e664b9f3c8ca65c
    // qiLink:  0x4e9f683A27a6BdAD3FC2764003759277e93696e6  https://snowtrace.io/address/0x4e9f683a27a6bdad3fc2764003759277e93696e6
    // qiDai:   0x835866d37AFB8CB8F8334dCCdaf66cf01832Ff5D  https://snowtrace.io/address/0x835866d37AFB8CB8F8334dCCdaf66cf01832Ff5D
    // qiUSDC:  0xBEb5d47A3f720Ec0a390d04b4d41ED7d9688bC7F  https://snowtrace.io/address/0xbeb5d47a3f720ec0a390d04b4d41ed7d9688bc7f
    // qiQi:    0x35Bd6aedA81a7E5FC7A7832490e71F757b0cD9Ce  https://snowtrace.io/address/0x35bd6aeda81a7e5fc7a7832490e71f757b0cd9ce
    address public qiToken;

    address[] public reward1ToWantRoute;
    address[] public reward2ToWantRoute;
    uint256 public lastHarvest;
    uint256 public supplyBal;

    /* ----- Constant Variables ----- */

    address public constant wrappedEther = address(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7); // WAVAX
    address public constant reward1 = address(0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5); // Qi token
    address public constant reward2 = wrappedEther; // Wavax token
    address public constant uniRouter = address(0x60aE616a2155Ee3d9A68541Ba4544862310933d4); // JoeRouter
    address public constant comptroller = address(0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4); // to claim reward

    /* ----- Events ----- */

    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        address initVault,
        address initAccessManager,
        address initQiToken,
        address[] memory initReward1ToWantRoute,
        address[] memory initReward2ToWantRoute
    ) public BaseStrategy(initVault, initAccessManager) {
        qiToken = initQiToken;
        reward1ToWantRoute = initReward1ToWantRoute;
        reward2ToWantRoute = initReward2ToWantRoute;

        _giveAllowances();
    }

    /* ----- External Functions ----- */

    function beforeDeposit() public override {
        super.beforeDeposit();
        updateSupplyBal();
    }

    function reward1ToWant() external view returns (address[] memory) {
        return reward1ToWantRoute;
    }

    function reward2ToWant() external view returns (address[] memory) {
        return reward2ToWantRoute;
    }

    /* ----- Public Functions ----- */

    function harvest() public override whenNotPaused {
        require(msg.sender == tx.origin || msg.sender == address(vault), 'StrategyBenqi: EOA_or_vault');

        // When pendingImplementation not zero address, means there is a new implement ready to replace.
        if (IComptroller(comptroller).pendingComptrollerImplementation() == address(0)) {
            uint256 beforeBal = balanceOfWant();

            _harvestAndSwap(0, reward1, reward1ToWantRoute);
            _harvestAndSwap(1, reward2, reward2ToWantRoute);

            uint256 wantHarvested = balanceOfWant().sub(beforeBal);
            uint256 fee = chargePerformanceFee(wantHarvested);
            deposit();

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, wantHarvested.sub(fee), balanceOf());
        } else {
            _withdrawAll();
            pause();
        }
    }

    function _harvestAndSwap(
        uint8 index,
        address reward,
        address[] memory route
    ) private {
        address[] memory markets = new address[](1);
        markets[0] = qiToken;
        IComptroller(comptroller).claimReward(index, address(this), markets);

        // in case of reward token is native token (ETH/BNB/Avax)
        uint256 toWrapBal = address(this).balance;
        if (toWrapBal > 0) {
            IWETH(wrappedEther).deposit{value: toWrapBal}();
        }

        uint256 rewardBal = IERC20(reward).balanceOf(address(this));

        // rewardBal == 0: means the current token reward ended
        // reward == want: no need to swap
        if (rewardBal > 0 && reward != want) {
            require(route.length > 0, 'StrategyBenqi: SWAP_ROUTE_INVALID');
            IJoeRouter(uniRouter).swapExactTokensForTokens(rewardBal, 0, route, address(this), now);
        }
    }

    function deposit() public override whenNotPaused nonReentrant {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            IVToken(qiToken).mint(wantBal);
            updateSupplyBal();
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 amount) public override nonReentrant {
        require(msg.sender == vault, 'StrategyBenqi: !vault');
        require(amount > 0, 'StrategyBenqi: !amount');

        uint256 wantBal = balanceOfWant();

        if (wantBal < amount) {
            IVToken(qiToken).redeemUnderlying(amount.sub(wantBal));
            updateSupplyBal();
            uint256 newWantBal = IERC20(want).balanceOf(address(this));
            require(newWantBal > wantBal, 'StrategyBenqi: !newWantBal');
            wantBal = newWantBal;
        }

        uint256 withdrawAmt = amount < wantBal ? amount : wantBal;

        uint256 fee = chargeWithdrawalFee(withdrawAmt);
        if (withdrawAmt > fee) {
            TransferHelper.safeTransfer(want, vault, withdrawAmt.sub(fee));
        }
        emit Withdraw(balanceOf());
    }

    function updateSupplyBal() public {
        supplyBal = IVToken(qiToken).balanceOfUnderlying(address(this));
    }

    function balanceOfPool() public view override returns (uint256) {
        return supplyBal;
    }

    /* ----- Internal Functions ----- */

    function _giveAllowances() internal override {
        TransferHelper.safeApprove(want, qiToken, 0);
        TransferHelper.safeApprove(want, qiToken, uint256(-1));
        TransferHelper.safeApprove(reward1, uniRouter, 0);
        TransferHelper.safeApprove(reward1, uniRouter, uint256(-1));
        TransferHelper.safeApprove(reward2, uniRouter, 0);
        TransferHelper.safeApprove(reward2, uniRouter, uint256(-1));
        TransferHelper.safeApprove(wrappedEther, uniRouter, 0);
        TransferHelper.safeApprove(wrappedEther, uniRouter, uint256(-1));
    }

    function _removeAllowances() internal override {
        TransferHelper.safeApprove(want, qiToken, 0);
        TransferHelper.safeApprove(reward1, uniRouter, 0);
        TransferHelper.safeApprove(reward2, uniRouter, 0);
        TransferHelper.safeApprove(wrappedEther, uniRouter, 0);
    }

    function _withdrawAll() internal {
        uint256 qiTokenBal = IERC20(qiToken).balanceOf(address(this));
        if (qiTokenBal > 0) {
            IVToken(qiToken).redeem(qiTokenBal);
        }
        updateSupplyBal();
    }

    /* ----- Admin Functions ----- */

    function retireStrat() external override {
        require(msg.sender == vault, 'StrategyBenqi: !vault');
        _withdrawAll();
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    function emergencyExit() external override onlyAdmin {
        _withdrawAll();
        uint256 wantBal = IERC20(want).balanceOf(address(this));
        if (wantBal > 0) {
            TransferHelper.safeTransfer(want, vault, wantBal);
        }
    }

    receive() external payable {}
}
