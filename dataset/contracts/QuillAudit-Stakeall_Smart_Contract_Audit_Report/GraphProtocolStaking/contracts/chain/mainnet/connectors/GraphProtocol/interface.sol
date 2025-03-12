// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

interface IGraphProtocolInterface {
    function delegate(address _indexer, uint256 _tokens)
        external
        payable
        returns (uint256 shares_);

    function undelegate(address _indexer, uint256 _shares)
        external
        returns (uint256 tokens_);

    function withdrawDelegated(address _indexer, address _delegateToIndexer)
        external
        returns (uint256 tokens_);
}
