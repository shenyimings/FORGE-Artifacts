pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;
import '../dependencies/token/ERC20/IERC20.sol';

interface IAToken is IERC20 {
    function burn(
        address user,
        address receiverOfUnderlying,
        uint256 amount
    ) external;

    function mint(address user, uint256 amount) external returns (bool);

    function transferUnderlyingTo(address target, uint256 amount) external returns (uint256);
}
