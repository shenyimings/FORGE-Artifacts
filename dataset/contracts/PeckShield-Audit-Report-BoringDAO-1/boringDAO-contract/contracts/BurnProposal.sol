// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BurnProposal is Ownable{

    using SafeMath for uint;

    bytes32 public constant TRUSTEE_ROLE = "TRUSTEE_ROLE";

    struct Proposal {
        string ethHash;
        string btcHash;
        uint256 voteCount;
        bool finished;
        bool isExist;
        mapping(address=>bool) voteState;
    }

    mapping(string => Proposal) public proposals;
    IRole public trustee;
    uint256 public diff=1;

    constructor(address _boringdao) public {
        trustee = IRole(_boringdao);
    }

    function setTrustee(address _trustee) public onlyOwner{
        trustee = IRole(_trustee);
    }

    function setDiff(uint256 _diff) public onlyOwner {
        diff = _diff;
    }

    function approve(string memory ethHash, string memory btcHash) public onlyTrustee{
        string memory key = string(abi.encodePacked(ethHash, btcHash));
        if (proposals[key].isExist == false) {
            Proposal memory p = Proposal({
                ethHash: ethHash,
                btcHash: btcHash,
                voteCount: 1,
                finished: false,
                isExist: true
            });
            proposals[key] = p;
            proposals[key].voteState[msg.sender] = true;
            emit VoteBurnProposal(ethHash, btcHash, msg.sender, p.voteCount);
        } else {
            Proposal storage p = proposals[key];
            if(p.voteState[msg.sender] == true) {
                return;
            }
            if(p.finished) {
                return;
            }
            p.voteCount = p.voteCount.add(1);
            p.voteState[msg.sender] = true;
            emit VoteBurnProposal(ethHash, btcHash, msg.sender, p.voteCount);
        }
        Proposal storage p = proposals[key];
        uint trusteeCount = getTrusteeCount();
        uint threshold = trusteeCount.mod(3) == 0 ? trusteeCount.mul(2).div(3) : trusteeCount.mul(2).div(3).add(diff);
        if (p.voteCount >= threshold) {
            p.finished = true;
            emit BurnProposalSuccess(ethHash, btcHash);
        }
    }

    function getTrusteeCount() internal view returns(uint){
        return trustee.getRoleMemberCount(TRUSTEE_ROLE);
    }


    modifier onlyTrustee {
        require(trustee.hasRole(TRUSTEE_ROLE, msg.sender), "Caller is not trustee");
        _;
    }

    event BurnProposalSuccess(
        string ethHash,
        string btcHash
    );

    event VoteBurnProposal(
        string ethHash,
        string btcHash,
        address voter,
        uint256 voteCount
    );
}

interface IRole {
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}