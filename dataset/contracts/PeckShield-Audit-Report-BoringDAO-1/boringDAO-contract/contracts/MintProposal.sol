// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./interface/IAddressResolver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/IMintProposal.sol";

contract MintProposal is IMintProposal, Ownable {
    using SafeMath for uint256;

    bytes32 public constant BORINGDAO = "BoringDAO";
    IAddressResolver addrReso;
    uint public diff=1;

    constructor(IAddressResolver _addrResovler) public {
        addrReso = _addrResovler;
    }

    struct Proposal {
        bytes32 tunnelKey;
        uint256 amount;
        uint256 voteCount;
        address creater;
        bool finished;
        bool isExist;
        mapping(address => bool) voteState;
        address to;
        string txid;
    }
    // mapping(address => bool) voteState;

    mapping(bytes32 => Proposal) public proposals;

    function setDiff(uint _diff) public onlyOwner {
        diff = _diff;
    }

    function approve(
        bytes32 _tunnelKey,
        string memory _txid,
        uint256 _amount,
        address to,
        address trustee,
        uint256 trusteeCount
    ) public override onlyBoringDAO returns (bool) {
        require(msg.sender == addrReso.key2address(BORINGDAO));
        bytes32 pid = keccak256(
            abi.encodePacked(_tunnelKey, _txid, _amount, to)
        );
        if (proposals[pid].isExist == false) {
            // new proposal
            Proposal memory p = Proposal({
                tunnelKey: _tunnelKey,
                to: to,
                txid: _txid,
                amount: _amount,
                creater: trustee,
                voteCount: 1,
                finished: false,
                isExist: true
            });
            proposals[pid] = p;
            proposals[pid].voteState[trustee] = true;
            emit VoteMintProposal(_tunnelKey, _txid, _amount, to, trustee, p.voteCount, trusteeCount);
        } else {
            // exist proposal
            Proposal storage p = proposals[pid];
            // had voted nothing to do more
            if(p.voteState[trustee] == true) {
                return false;
            }
            // proposal finished noting to do more
            if (p.finished) {
                return false;
            }
            p.voteCount = p.voteCount.add(1);
            p.voteState[trustee] = true;
            emit VoteMintProposal(_tunnelKey, _txid, _amount, to, trustee, p.voteCount, trusteeCount);
        }
        Proposal storage p = proposals[pid];
        uint threshold = trusteeCount.mod(3) == 0 ? trusteeCount.mul(2).div(3) : trusteeCount.mul(2).div(3).add(diff);
        if (p.voteCount >= threshold) {
            p.finished = true;
            return true;
        } else {
            return false;
        }
    }

    modifier onlyBoringDAO {
        require(msg.sender == addrReso.key2address(BORINGDAO), "MintProposal::caller is not boringDAO");
        _;
    }

    event VoteMintProposal(
        bytes32 _tunnelKey,
        string _txid,
        uint256 _amount,
        address to,
        address trustee,
        uint votedCount,
        uint256 trusteeCount
    );

}
