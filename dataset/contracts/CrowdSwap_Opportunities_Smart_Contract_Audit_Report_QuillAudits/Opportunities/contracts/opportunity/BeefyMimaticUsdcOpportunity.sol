// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./Opportunity.sol";
import "../libraries/UniERC20Upgradeable.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IBeefyVault.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title mimatic/usdc Opportunity
 * @notice The contract is used to add/remove liquidity in mimatic/usdc pool and
 * stake/unstake the corresponding LP token
 */
contract BeefyMimaticUsdcOpportunity is Opportunity {

    using UniERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public swapContract;
    IUniswapV2Router02 public router;
    IBeefyVault public vault;

    /**
     * @dev The contract constructor
     * @param _tokenMimatic The address of the MIM token
     * @param _tokenUsdc The address of the USDC token
     * @param _pairMimaticUsdc The address of the pair USDC/MIMATIC
     * @param _feeTo The address of recipient of the fees
     * @param _addLiquidityFee The initial fee of Add Liquidity step
     * @param _removeLiquidityFee The initial fee of Remove Liquidity step
     * @param _stakeFee The initial fee of Stake step
     * @param _unstakeFee The initial fee of Unstake step
     * @param _swapContract The address of the CrowdSwap Swap Contract
     * @param _router The address of the QuickSwap Router Contract
     * @param _vault The address of the Stake LP Contract
     */
    function initialize(
        address _tokenMimatic,
        address _tokenUsdc,
        address _pairMimaticUsdc,
        address payable _feeTo,
        uint256 _addLiquidityFee,
        uint256 _removeLiquidityFee,
        uint256 _stakeFee,
        uint256 _unstakeFee,
        address _swapContract,
        address _router,
        address _vault
    ) public initializer {
        Opportunity._initializeContracts(
            _tokenMimatic,
            _tokenUsdc,
            _pairMimaticUsdc
        );
        Opportunity._initializeFees(
            _feeTo,
            _addLiquidityFee,
            _removeLiquidityFee,
            _stakeFee,
            _unstakeFee
        );
        swapContract = _swapContract;
        router = IUniswapV2Router02(_router);
        vault = IBeefyVault(_vault);
    }

    function setSwapContract(address _address) external onlyOwner {
        require(_address != address(0), "oe12");
        swapContract = _address;
    }

    function setRouter(address _address) external onlyOwner {
        require(_address != address(0), "oe12");
        router = IUniswapV2Router02(_address);
    }

    function setVault(address _address) external onlyOwner {
        require(_address != address(0), "oe12");
        vault = IBeefyVault(_address);
    }

    function swap(
        IERC20Upgradeable _fromToken,
        uint256 _amount,
        bytes calldata _data
    ) internal override returns (uint256) {
        // gas savings
        address _swapContract = swapContract;
        if (!_fromToken.isETH()) {
            _fromToken.uniApprove(_swapContract, _amount);
        }
        bytes memory returnData = AddressUpgradeable.functionCallWithValue(
            _swapContract,
            _data,
            _fromToken.isETH() ? _amount : 0
        );
        return abi.decode(returnData, (uint256));
    }

    function addLiquidity(
        AddLiqDescriptor memory _addLiqDescriptor
    ) internal override returns (uint256, uint256, uint256) {
        // gas savings
        IUniswapV2Router02 _router = router;
        tokenA.uniApprove(address(_router), _addLiqDescriptor.amountADesired);
        tokenB.uniApprove(address(_router), _addLiqDescriptor.amountBDesired);
        return _router.addLiquidity(
            address(tokenA),
            address(tokenB),
            _addLiqDescriptor.amountADesired,
            _addLiqDescriptor.amountBDesired,
            _addLiqDescriptor.amountAMin,
            _addLiqDescriptor.amountBMin,
            address(this),
            _addLiqDescriptor.deadline
        );
    }

    function removeLiquidity(
        RemoveLiqDescriptor memory _removeLiqDescriptor
    ) internal override returns (uint256, uint256) {
        IUniswapV2Router02 _router = router; // gas savings
        pair.uniApprove(address(_router), _removeLiqDescriptor.amount);
        return _router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            _removeLiqDescriptor.amount,
            _removeLiqDescriptor.amountAMin,
            _removeLiqDescriptor.amountBMin,
            _removeLiqDescriptor.receiverAccount,
            _removeLiqDescriptor.deadline
        );
    }

    function stake(address _userAddress, uint256 _amount) internal override {
        IBeefyVault _vault = vault; // gas savings
        pair.uniApprove(address(_vault), _amount);
        _vault.deposit(_amount);
        IERC20Upgradeable(_vault).safeTransfer(_userAddress, _vault.balanceOf(address(this)));
    }

    function unstake(
        uint256 _amount
    ) internal override returns (uint256, uint256) {
        IBeefyVault _vault = vault; // gas savings
        IERC20Upgradeable(_vault).safeTransferFrom(msg.sender, address(this), _amount);
        _vault.withdraw(_amount);
        return (0, 0);
    }

}
