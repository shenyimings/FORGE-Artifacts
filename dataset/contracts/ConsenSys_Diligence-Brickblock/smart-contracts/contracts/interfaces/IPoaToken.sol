pragma solidity 0.4.24;

interface IPoaToken {
  function initializeToken
  (
    bytes32 _name32, // bytes32 of name string
    bytes32 _symbol32, // bytes32 of symbol string
    address _issuer,
    address _custodian,
    address _registry,
    uint256 _totalSupply // token total supply
  )
    external
    returns (bool);

  function issuer()
    external
    view
    returns (address);

  function startPreFunding()
    external
    returns (bool);

  function pause()
    external;

  function unpause()
    external;

  function terminate()
    external
    returns (bool);

  function proofOfCustody()
    external
    view
    returns (string);
}
