// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import './ElectionPoll.sol';
import '../access/Adminnable.sol';

contract ElectionFactory is Adminnable {
  uint256 public pollCount;
  PollInfo[] public polls;
  mapping(address => PollInfo) public addressToPoll;

  struct PollInfo {
    uint256 index;
    address addr;
    uint256 timestamp;
  }

  event ElectionPollCreated(address _poll, address indexed _creater, string indexed _name);

  constructor(IAdminManage _admin) Adminnable(_admin) {}

  function createPoll(
    IERC20 _voteToken,
    address _receiveAddress,
    string memory _name,
    uint256 _startBlock,
    uint256 _endBlock,
    uint256 _minimumToken,
    uint256 _maximumToken,
    bool _burnType,
    bool _multiType,
    uint8 _burnPercent
  ) external onlyAdmin {
    address addr;
    bytes memory bytecode;
    {
      bytecode = getContractBytecode(_voteToken, _receiveAddress, _name);
      addr = deployContract(bytecode);
    }

    ElectionPoll(addr).initialize(
      _startBlock,
      _endBlock,
      _minimumToken,
      _maximumToken,
      _burnType,
      _multiType,
      _burnPercent
    );

    PollInfo memory pollInfo = PollInfo(pollCount, addr, block.timestamp);
    polls.push(pollInfo);
    pollCount++;
    addressToPoll[addr] = pollInfo;

    emit ElectionPollCreated(addr, msg.sender, _name);
  }

  function deployContract(bytes memory bytecode) internal returns (address addr) {
    bytes32 salt = keccak256(abi.encodePacked(block.number, msg.sender));

    assembly {
      addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
      if iszero(extcodesize(addr)) {
        revert(0, 0)
      }
    }
  }

  function getContractBytecode(
    IERC20 _voteToken,
    address _receiveAddress,
    string memory _name
  ) internal view returns (bytes memory) {
    bytes memory bytecode = type(ElectionPoll).creationCode;

    return abi.encodePacked(bytecode, abi.encode(getAdminManage(), _voteToken, _receiveAddress, _name));
  }
}
