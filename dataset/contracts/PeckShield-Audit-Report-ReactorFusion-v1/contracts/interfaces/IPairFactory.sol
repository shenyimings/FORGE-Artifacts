pragma solidity ^0.8.13;

import "./IPair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPairFactory {
    function allPairsLength() external view returns (uint);

    function isPair(address pair) external view returns (bool);

    function voter() external view returns (address);

    function tank() external view returns (address);

    function getInitializable() external view returns (address, address, bool);

    function getFee(bool _stable) external view returns (uint256);

    function isPaused() external view returns (bool);

    function getPair(
        IERC20 tokenA,
        IERC20 token,
        bool stable
    ) external view returns (IPair);

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);
}
