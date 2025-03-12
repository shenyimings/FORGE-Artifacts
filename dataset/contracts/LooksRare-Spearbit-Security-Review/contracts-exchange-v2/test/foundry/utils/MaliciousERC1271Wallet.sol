// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ILooksRareProtocol} from "../../../contracts/interfaces/ILooksRareProtocol.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

contract MaliciousERC1271Wallet {
    enum FunctionToReenter {
        ExecuteTakerAsk,
        ExecuteTakerBid,
        ExecuteMultipleTakerBids
    }

    ILooksRareProtocol private immutable looksRareProtocol;
    FunctionToReenter private functionToReenter;

    constructor(address _looksRareProtocol) {
        looksRareProtocol = ILooksRareProtocol(_looksRareProtocol);
    }

    function isValidSignature(bytes32, bytes calldata signature) external returns (bytes4 magicValue) {
        if (functionToReenter == FunctionToReenter.ExecuteTakerAsk) {
            _executeTakerAsk(signature);
        } else if (functionToReenter == FunctionToReenter.ExecuteTakerBid) {
            _executeTakerBid(signature);
        } else if (functionToReenter == FunctionToReenter.ExecuteMultipleTakerBids) {
            _executeMultipleTakerBids();
        }

        magicValue = this.isValidSignature.selector;
    }

    function setFunctionToReenter(FunctionToReenter _functionToReenter) external {
        functionToReenter = _functionToReenter;
    }

    function _executeTakerAsk(bytes calldata signature) private {
        OrderStructs.TakerAsk memory takerAsk;
        OrderStructs.MakerBid memory makerBid;
        OrderStructs.MerkleTree memory merkleTree;

        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, merkleTree, address(this));
    }

    function _executeTakerBid(bytes calldata signature) private {
        OrderStructs.TakerBid memory takerBid;
        OrderStructs.MakerAsk memory makerAsk;
        OrderStructs.MerkleTree memory merkleTree;

        looksRareProtocol.executeTakerBid(takerBid, makerAsk, signature, merkleTree, address(this));
    }

    function _executeMultipleTakerBids() private {
        OrderStructs.TakerBid[] memory takerBids = new OrderStructs.TakerBid[](2);
        OrderStructs.MakerAsk[] memory makerAsks = new OrderStructs.MakerAsk[](2);
        bytes[] memory signatures = new bytes[](2);
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](2);

        looksRareProtocol.executeMultipleTakerBids(takerBids, makerAsks, signatures, merkleTrees, address(this), false);
    }
}
