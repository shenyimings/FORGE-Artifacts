pragma solidity 0.4.24;

interface IPoaManager {
  function isActiveToken(
    address _tokenAddress
  )
    external
    view
    returns (bool);
}
