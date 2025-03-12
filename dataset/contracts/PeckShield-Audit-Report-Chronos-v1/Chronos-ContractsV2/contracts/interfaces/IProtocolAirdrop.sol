// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
interface IProtocolAirdrop {
  function deposit ( uint256 amount ) external;
  function giveToProtocol ( address _to, uint256 amount ) external;
  function owner (  ) external view returns ( address );
  function setDepositor ( address depositor, bool _status ) external;
  function setOwner ( address _owner ) external;
  function setVe ( address _ve ) external;
  function token (  ) external view returns ( address );
  function ve (  ) external view returns ( address );
  function withdraw ( uint256 amount ) external;
}
