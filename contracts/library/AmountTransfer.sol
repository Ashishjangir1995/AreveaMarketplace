// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
        @notice this  contract contains erc20 token transfer related functions and library.
       
*/
library AmountTransfer {
    function bidAmountTransfer(uint256 _buyAmount, address _erc20, address _to) internal {
        require(
            IERC20(_erc20).transferFrom(_to, address(this), _buyAmount),
            "allowance not enough"
        );
    }

     /**
     * @dev nativeAmountTransfer internal function 
     * This internal function is to check the amount transfered or not 
     * Emits a {Transfer amount} event.
    
     */

    function nativeAmountTransfer(address _nftSeller, uint256 _buyAmount)
        internal
    {
        (bool success, ) = _nftSeller.call{value: _buyAmount}("");
        require(success, "refund failed");
    }
   /**
     * @dev Moves `amount` of tokens from `from` to `address(this)`
     * This internal function is equivalent to {transfer}, and can be used to transfer token to nft seller 
     * Emits a {Transfer} event.
    
     */
    function tokenAmountTransfer(
        address _to,
        address _nftSeller,
        address _erc20,
        uint256 _buyAmount
    ) internal {
        require(
            IERC20(_erc20).transferFrom(_to, address(this), _buyAmount),
            "allowance not enough"
        );
        IERC20(_erc20).transfer(_nftSeller, _buyAmount);
    }
}
