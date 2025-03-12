pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;
import "../dependencies/token/ERC20/IERC20.sol";

interface IAToken is IERC20{

  function burn(
    address user,
    address receiverOfUnderlying,
    uint256 amount//,
//    uint256 index
  ) external;


  function mint(
    address user,
    uint256 amount//,
    //uint256 index
  ) external returns (bool);

}
