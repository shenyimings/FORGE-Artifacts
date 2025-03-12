//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

import "../interfaces/IPriceObserver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Stores a finite sequence of price observations
contract PriceObserver is Ownable, IPriceObserver {
    /// Maximum number of elements storable by the backing array
    uint256 public constant MAX_NUM_ELEMS = 24;

    /// Current number of elements stored by the backing array
    uint256 public numElems;

    /// Backing array for storing price data
    int256[MAX_NUM_ELEMS] public observations;

    /// Writer -- only address allowed to add data to the backing array
    address writer;

    /**
     * @notice Enforces that the caller is the associated writer of this
     *          contract
     */
    modifier onlyWriter() {
        require(msg.sender == writer, "PO: Permission denied");
        _;
    }

    /**
     * @notice Returns the capacity of the backing array (i.e., the maximum
     *          number of price observations able to be stored by this contract)
     * @return Maximum number of price observations that can be stored
     * @dev `MAX_NUM_ELEMS`
     */
    function capacity() public pure override returns (uint256) {
        return MAX_NUM_ELEMS;
    }

    /**
     * @notice Returns the current number of price observations stored
     * @return Current number of price observations stored
     * @dev Should always be less than or equal to `capacity`
     * @dev `numElems`
     */
    function length() public view override returns (uint256) {
        return numElems;
    }

    /**
     * @notice Retrieves the `i`th price observation
     * @param i Period to retrieve the price observation of
     * @return `i`th price observation
     * @dev Throws if index is out of bounds (i.e., `i >= length()`)
     */
    function get(uint256 i) external view override returns (int256) {
        require(i < length(), "PO: Out of bounds");
        return observations[i];
    }

    /**
     * @notice Retrieves all price observations
     * @return Backing array of all price observations
     * @dev Note that, due to this view simply returning a reference to the
     *      backing array, it's possible for there to be null prices (i.e., 0)
     */
    function getAll() external view override returns (int256[MAX_NUM_ELEMS] memory) {
        return observations;
    }

    /**
     * @notice Adds a new price observation to the contract
     * @param x Price
     * @return Whether or not an existing price observation was rotated out
     * @dev If the backing array is full (i.e., `length() == capacity()`, then
     *      it is rotated such that the oldest price observation is deleted
     * @dev Only callable by the associated writer for this contract
     */
    function add(int256 x) external override onlyWriter returns (bool) {
        if (full()) {
            leftRotateWithPad(x);
            return true;
        } else {
            observations[length()] = x;
            numElems += 1;
            return false;
        }
    }

    /**
     * @notice Sets the associated writer address for this contract
     * @param _writer Address of the new writer
     * @dev Only callable by the owner of this contract
     * @dev Throws if `_writer` is the null address
     * @dev Emits a `WriterChanged` event on success
     */
    function setWriter(address _writer) external onlyOwner {
        require(_writer != address(0), "PO: Null address not allowed");
        writer = _writer;
        emit WriterChanged(_writer);
    }

    /**
     * @notice Returns the current writer of this contract
     * @return Address of the writer for this contract
     * @dev `writer`
     */
    function getWriter() external view returns (address) {
        return writer;
    }

    /**
     * @notice Determines whether or not the backing array is full
     * @return Flag indicating whether the backing array is full or not
     * @dev `length() == capacity()`
     */
    function full() private view returns (bool) {
        return length() == capacity();
    }

    /**
     * @notice Resets the backing array and clears all of its stored prices
     * @dev Only callable by the owner of this contract
     */
    function clear() external onlyOwner {
        numElems = 0;
        delete observations;
    }

    /**
     * @notice Rotates observations array to the **left** by one element and
     *          sets the last element of `xs` to `x`
     * @param x Element to "rotate into" observations array
     */
    function leftRotateWithPad(int256 x) private {
        uint256 n = length();

        /* linear scan over the [1, n] subsequence */
        for (uint256 i = 1; i < n; i++) {
            observations[i - 1] = observations[i];
        }

        /* rotate `x` into `observations` from the right (remember, we're
         * **left** rotating -- with padding!) */
        observations[n - 1] = x;
    }
}
