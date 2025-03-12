pragma solidity ^0.4.18;

import "./IFeed.sol";


interface IPPFFactory {
  event NewPPF(address ppf, address indexed operator, address indexed operatorOwner);

  function newPPF(address operator, address operatorOwner) external returns (IFeed);
}