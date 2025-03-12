// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import "./interfaces/uniswap/INonfungiblePositionManager.sol";
import "./token/Abra.sol";

/**
 * @dev LiquidityMaster controls the protocol-owned liquidity. It can add ranges at V3 pools and change single sided
 * ABRA liquidity at any pool. It can't change the liquidity of the range if the current price is within that range.
 * 
 * The goal of this contract is to keep ability to change ABRA allocations beetween pools, for example to rebalance 
 * the supply of ABRA between pools, or to a new pool. At the same time it ensures that underlying luqidity of the 
 * second token can't be withdrawn by the protocol.
 */
contract LiquidityMaster is AccessControlUpgradeable, UUPSUpgradeable {

    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE"); // timelock
    bytes32 public constant CONSTRAINT_MANAGER_ROLE = keccak256("CONSTRAINT_MANAGER_ROLE"); // timelock
    bytes32 public constant POSITION_MANAGER_ROLE = keccak256("POSITION_MANAGER_ROLE");

    struct MintParams {
        address token;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 abraAmount;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 abraAmount;
        uint256 deadline;
    }

    mapping(uint16 => address) public recipientByChainId;

    mapping(address => bool) private permittedAssets;


    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    Abra public immutable abra;

    constructor(address _nonfungiblePositionManager, address _abra) {
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        abra = Abra(_abra);
    }

    function initialize() external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function permitAsset(address asset, bool permit) external onlyRole (CONSTRAINT_MANAGER_ROLE) {
        permittedAssets[asset] = permit;
    }

    function setRecipientForChain(uint16 _dstChainId, address _recipient) external onlyRole (CONSTRAINT_MANAGER_ROLE) {
        recipientByChainId[_dstChainId] = _recipient;
    }

    function mintLiquidity(MintParams calldata params)
        external
        onlyRole(POSITION_MANAGER_ROLE)
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        _checkAssetPermitted(params.token);
        abra.approve(address(nonfungiblePositionManager), params.abraAmount);

        address token0;
        address token1;
        (token0, token1, amount0, amount1) = params.token < address(abra)
                ? (params.token, address(abra), uint256(0), params.abraAmount)
                : (address(abra), params.token, params.abraAmount, uint256(0));

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams(
            token0,
            token1,
            params.fee,
            params.tickLower,
            params.tickUpper,
            amount0,
            amount1,
            amount0,
            amount1,
            address(this),
            params.deadline
        );
        return nonfungiblePositionManager.mint(mintParams);
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        onlyRole(POSITION_MANAGER_ROLE)
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (,,address token0, address token1,,,,,,,,) = nonfungiblePositionManager.positions(params.tokenId);

        _checkAssetPermitted(token0 == address(abra) ? token1 : token0);

        (uint256 increaseAmount0, uint256 increaseAmount1) = token1 == address(abra)
            ? (uint256(0), params.abraAmount)
            : (params.abraAmount, uint256(0));

        abra.approve(address(nonfungiblePositionManager), params.abraAmount);

        return nonfungiblePositionManager.increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams(
                params.tokenId,
                increaseAmount0,
                increaseAmount1,
                increaseAmount0,
                increaseAmount1,
                params.deadline
            ));
    }

    function decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams calldata params)
        external
        onlyRole(POSITION_MANAGER_ROLE)
        returns (uint256 amount0, uint256 amount1)
    {
        (,,address token0, address token1,,,,,,,,) = nonfungiblePositionManager.positions(params.tokenId);

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
        require(token0 == address(abra) ? amount1 == 0 : amount0 == 0, "LM: can not decrease liquidity");
    }

    function sendAbraToChain(uint16 _dstChainId, uint256 amount) payable external onlyRole(POSITION_MANAGER_ROLE) {
        address target = recipientByChainId[_dstChainId];
        require(target != address(0), "LM: no recipient for target chain");
        abra.sendFrom{value: msg.value}(address(this), _dstChainId, abi.encodePacked(target), amount, payable(msg.sender), msg.sender, "");
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADE_ROLE) {}

    function _checkAssetPermitted(address token) private view {
        require(permittedAssets[token], "LM: asset not permitted");
    }

}