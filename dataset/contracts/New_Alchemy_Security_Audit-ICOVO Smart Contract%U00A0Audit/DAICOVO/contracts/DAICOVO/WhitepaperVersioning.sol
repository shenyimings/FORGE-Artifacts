pragma solidity ^0.4.21;

/**
 * @title WhitepaperVersioning
 * @dev Bi-directional Linked list of Whitepapers.
 * @dev Contents of whitepapers is expected to be stored in IPFS.
 * @dev Put IPFS hash of the first version of whitepaper in your project's contract
 * @dev such as a project token contract, or token sale contractl.
 */
contract WhitepaperVersioning {
    mapping (string => Whitepaper) private whitepapers;
    event Post(string indexed ipfsHash, uint8 version, address indexed author);

    struct Whitepaper {
        uint8 version;
        address author;
        string prev;
        string next;
        bool initialized;
    }

    /**
     * @dev Constructor
     * @dev Doing nothing.
     */
    function WhitepaperVersioning () public {}

    /**
     * @dev Function to post a new whitepaper
     * @param _ipfsHash string IPFS hash of the posting whitepaper
     * @param _version uint8 Version number in integer
     * @param _prev IPFS hash of the previous version whitepaper (if initial version, set "HEAD")
     * @return status bool
     */
    function post (string _ipfsHash, uint8 _version, string _prev) public returns (bool) {
        // Check if the IPFS hash doesn't exist already.
        require(!whitepapers[_ipfsHash].initialized);

        // Check if the specified version is counted up
        require(_version > whitepapers[_prev].version);
    
        // Check if a previous whitepaper's author is identical to the posting whitepaper's author
        // or the posting whitepaper is the initial version (HEAD version)
        require(keccak256(_prev) == keccak256("HEAD") || whitepapers[_prev].author == msg.sender);

        // Check if there is no fork from the previous version
        require(bytes(whitepapers[_prev].next).length == 0);
    
        whitepapers[_prev].next = _ipfsHash;
        whitepapers[_ipfsHash] = Whitepaper(_version, msg.sender, _prev, "", true);
        emit Post(_ipfsHash, _version, msg.sender);
        return true;
    }
  
    /**
     * @dev Look up whitepaper by IPFS hash as a key
     * @param _ipfsHash string IPFS hash of the whitepaper to look up
     * @return ipfsHash string IPFS hash of the whitepaper
     * @return version uint8 Version number in integer
     * @return author address Address of an account who posted the whitepaper
     * @return prev string IPSS hash of the previous version whitepaper (if initial version, it's "HEAD")
     * @return next string IPFS hash of the next version whitepaper if available
     */
    function get (string _ipfsHash) public view returns (
        string ipfsHash,
        uint8 version,
        address author,
        string prev,
        string next
    ) {
        return (
           _ipfsHash,
            whitepapers[_ipfsHash].version,
            whitepapers[_ipfsHash].author,
            whitepapers[_ipfsHash].prev,
            whitepapers[_ipfsHash].next
        );
    }
}

