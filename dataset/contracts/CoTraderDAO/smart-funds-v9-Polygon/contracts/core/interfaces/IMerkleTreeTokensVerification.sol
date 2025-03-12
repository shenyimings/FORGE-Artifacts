interface IMerkleTreeTokensVerification {
  function verify(
    address _leaf,
    bytes32 [] calldata proof,
    uint256 [] calldata positions
  )
    external
    view
    returns (bool);
}
