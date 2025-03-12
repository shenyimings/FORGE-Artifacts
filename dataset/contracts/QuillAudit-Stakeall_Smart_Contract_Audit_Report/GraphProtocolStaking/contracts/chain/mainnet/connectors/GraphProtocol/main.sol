// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "./interface.sol";
import {Helpers} from "./helpers.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * GraphProtocolStaking helps to perform delegation, unndelegation and withdrawal
 * of GRT token.
 */
contract GraphProtocolStaking is Helpers {
    string public constant name = "GraphProtocol-v1";

    using SafeMath for uint256;

    /**
     * @notice It allows delegation to single graph indexer.
     *
     * @param indexer Indexer address to delegate.
     * @param amount Total amount to be delegated.
     * @param getId ID to retrieve amt.
     */
    function delegate(
        address indexer,
        uint256 amount,
        uint256 getId
    ) external {
        require(indexer != address(0));
        uint256 delegationAmount = getUint(getId, amount);
        grtTokenAddress.approve(address(graphProxy), delegationAmount);
        graphProxy.delegate(indexer, delegationAmount);
    }

    /**
     * @notice It allows delegation to multiple graph indexers.
     *
     * @param indexers List of indexer addresses to delegate.
     * @param amount Total amount to be delegated.
     * @param portions List of percentage from `amount` to delegate to each indexer.
     * @param getId ID to retrieve amt.
     */
    function delegateMultiple(
        address[] memory indexers,
        uint256 amount,
        uint256[] memory portions,
        uint256 getId
    ) external payable {
        require(amount > 0, "Invalid amount");
        require(
            portions.length == indexers.length,
            "Indexer and Portion length doesnt match"
        );
        uint256 delegationAmount = getUint(getId, amount);
        uint256 totalPortions = 0;

        uint256[] memory indexersAmount = new uint256[](indexers.length);
        uint256 portionsSize = portions.length;
        for (uint256 position = 0; position < portionsSize; position++) {
            indexersAmount[position] = portions[position]
                .mul(delegationAmount)
                .div(PORTIONS_SUM);
            totalPortions = totalPortions + portions[position];
        }

        require(totalPortions == PORTIONS_SUM, "Portion Mismatch");

        grtTokenAddress.approve(address(graphProxy), delegationAmount);

        for (uint256 i = 0; i < portionsSize; i++) {
            require(indexers[i] != address(0), "Invalid indexer");
            graphProxy.delegate(indexers[i], indexersAmount[i]);
        }
    }

    /**
     * @notice It allows undelegation of shares from an indexer.
     *
     * @param _indexer Indexer address from whom undelegation of shares is to be done.
     * @param _shares Number of shares to be undelegated
     */
    function undelegate(address _indexer, uint256 _shares) external payable {
        require(_indexer != address(0), "!Invalid Address");
        graphProxy.undelegate(_indexer, _shares);
    }

    /**
     * @notice It allows undelegation of shares from multiple indexers.
     *
     * @param _indexers List of indexers from whom to undelegation is to be done.
     * @param _shares List of number of shares to be undelegated corresponding to
     *                each indexer.
     */
    function undelegateMultiple(
        address[] memory _indexers,
        uint256[] memory _shares
    ) external payable {
        require(
            _indexers.length == _shares.length,
            "Indexers & shares mismatch"
        );

        uint256 indexersSize = _indexers.length;
        for (uint256 i = 0; i < indexersSize; i++) {
            require(_indexers[i] != address(0), "Invalid indexer");
            graphProxy.undelegate(_indexers[i], _shares[i]);
        }
    }

    /**
     * @notice It allows for withdrawal of GRT from indexer to an addresss.
     *
     * @param _indexer Indexer address from whom withdrawal is to be done.
     * @param _delegateToIndexer Address to which amount is to be send. 
     *                           If it's set to 0 then withdraw happens  
     *                           otherwise delegation happens to
     *                           _delegateToIndexer.
     */
    function withdrawDelegated(address _indexer, address _delegateToIndexer)
        external
        payable
    {
        require(_indexer != address(0), "Invalid indexer address");
        graphProxy.withdrawDelegated(_indexer, _delegateToIndexer);
    }

    /**
     * @notice It allows for withdrawal of GRT from multiple indexers.
     *
     * @param _indexers List of indexers from whom withdrawal is to be done.
     * @param _delegateToIndexers List of addresses to send withdrawal amount.
     */
    function withdrawMultipleDelegate(
        address[] memory _indexers,
        address[] memory _delegateToIndexers
    ) external payable {
        uint256 indexersSize = _indexers.length;
        for (uint256 i = 0; i < indexersSize; i++) {
            require(_indexers[i] != address(0), "Invalid indexer");
            graphProxy.withdrawDelegated(_indexers[i], _delegateToIndexers[i]);
        }
    }
}
