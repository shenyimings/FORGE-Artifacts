// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.17;

contract MultiSign {
    // All the signers
    address[] public signers;
    // the index+1 of  signer in the signers
    mapping(address => uint8) iSigner;
    // The required count of signers
    uint8 public requireCount;

    event SignerAddition(address indexed signer);
    event SignerRemoval(address indexed signer);
    event ChangeRequireCount(uint8 changeRequireCount);

    // signer only modifier.
    modifier onlySigner() {
        require(iSigner[msg.sender] > 0, "not signer");
        _;
    }

    constructor(address[] memory _signers, uint8 _requireCount) {
        for (uint8 i = 0; i < _signers.length; i++) {
            require(
                iSigner[_signers[i]] == 0 && _signers[i] != address(0),
                "invalid or duplicated signer"
            );
            iSigner[_signers[i]] = i + 1;
        }
        signers = _signers;
        requireCount = _requireCount;
    }

    address public addingSigner;
    uint8 public addingCount;
    mapping(address => mapping(address => bool)) public isAdded; // singer => addingSigner => isAdded

    // To add a signer
    function addSigner(address signer) external onlySigner {
        if (addingSigner == address(0)) {
            require(iSigner[signer] == 0, "already exist");
            addingSigner = signer;
            //set isAdded empty
            for (uint8 i = 0; i < signers.length; i++) {
                delete isAdded[msg.sender][signer];
            }
        } else {
            require(addingSigner == signer, "wrong signer");
        }

        if (!isAdded[msg.sender][signer]) {
            isAdded[msg.sender][signer] = true;
            addingCount++;
        }

        if (addingCount >= requireCount) {
            signers.push(signer);
            iSigner[signer] = uint8(signers.length);

            addingSigner = address(0);
            addingCount = 0;

            emit SignerAddition(signer);
        }
    }

    uint8 public removingIndex;
    uint8 public removingCount;
    mapping(address => mapping(uint8 => bool)) public isRemoved; // singer => removingIndex => isRemoved

    // To remove a signer
    function removeSigner(uint8 index) external onlySigner {
        if (removingIndex == 0) {
            require(index < signers.length, "wrong index");
            removingIndex == index;
            //set isRemoved empty
            for (uint8 i = 0; i < signers.length; i++) {
                delete isRemoved[msg.sender][i];
            }
        } else {
            require(removingIndex == index, "mismatched index");
        }

        if (!isRemoved[msg.sender][index]) {
            isRemoved[msg.sender][index] = true;
            removingCount++;
        }

        if (removingCount >= requireCount) {
            address toDelAddr = signers[index];
            address lastSigner = signers[signers.length - 1];
            signers[index] = lastSigner;
            iSigner[lastSigner] = index + 1;
            delete iSigner[toDelAddr];
            signers.pop();

            removingIndex = 0;
            removingCount = 0;

            emit SignerRemoval(toDelAddr);
        }
    }

    uint8 public newRequireCount;
    uint8 public changingCount;
    mapping(address => bool) public isChangeCount; // singer => siChangeCount;

    // to change the requireCount
    function changeRequireCount(uint8 newCount) external onlySigner {
        if (newRequireCount == 0) {
            require(newCount <= signers.length, "wrong count");
            newRequireCount == newCount;
            //set isChangeCount empty
            for (uint8 i = 0; i < signers.length; i++) {
                delete isChangeCount[msg.sender];
            }
        } else {
            require(newCount == newRequireCount, "mismatched count");
        }

        if (!isChangeCount[msg.sender]) {
            isChangeCount[msg.sender] = true;
            changingCount++;
        }

        if (changingCount >= requireCount) {
            requireCount = newCount;

            newRequireCount = 0;
            changingCount = 0;

            emit ChangeRequireCount(newCount);
        }
    }
}
