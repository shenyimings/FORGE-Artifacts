pragma solidity =0.6.12;

import './Swap.sol';
import "../interfaces/ISwapCreator.sol";

contract SwapCreator is ISwapCreator {

    function create(
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        uint256 _withdrawFee,
        address timeLock
    ) external override returns (address) {
        Swap swap = new Swap();
        swap.initialize(_pooledTokens,
            decimals,
            lpTokenName,
            lpTokenSymbol,
            _a,
            _fee,
            _adminFee,
            _withdrawFee,
            msg.sender
        );
        swap.transferOwnership(timeLock);

        return address(swap);
    }
}