// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;
import "../libraries/BinarySearchTree.sol";
import "hardhat/console.sol";

contract BST {
    using BinarySearchTreeLib for BinarySearchTreeLib.Tree;

    BinarySearchTreeLib.Tree internal tree;

    function insert(uint256 value) public {
        tree.insert(value);
    }

    function root() public view returns (uint256 rootValue) {
        rootValue = tree.root;
        // console.log("root", rootValue, tree.rootLast);
    }

    function trim(uint256 start, uint256 end) public {
        // uint256 newRoot = tree.trimTree(start, end);
        // console.log(
        //     "trim check",
        //     tree.root,
        //     newRoot,
        //     tree.nodes[tree.root].right
        // );
        // console.log("trim check.1", tree.nodes[tree.root].left);
        // console.log(
        //     "trim check1",
        //     tree.nodes[tree.nodes[tree.root].right].left
        // );
        // console.log(
        //     "trim check1",
        //     tree.nodes[tree.nodes[tree.root].right].right
        // );
    }

    function deleteNode(uint256 value) public {
        tree.deleteNode(value);
    }

    function returnList(
        uint256 start,
        uint256 end
    )
        public
        returns (uint256[] memory outList, uint256[] memory outListFuture)
    {
        tree.processExpiriesListNTrimTree(start, end);
        outList = tree.getExpiriesList();
        if (outList.length >= 1) {
            for (uint256 i = 0; i < outList.length; i++) {
                console.log(
                    "tillNow",
                    tree.rootLast,
                    outList.length,
                    outList[i]
                );
            }
        }
        outListFuture = tree.getFutureExpiriesList();
        if (outListFuture.length >= 1) {
            for (uint256 i = 0; i < outListFuture.length; i++) {
                console.log(
                    "startNow",
                    tree.rootLast,
                    outListFuture.length,
                    outListFuture[i]
                );
            }
        }
    }
}
