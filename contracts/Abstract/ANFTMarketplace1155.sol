// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/INFTMarketplace1155.sol";
import "../library/AmountTransfer.sol";
  /*
        @notice abstract contract ANFTMarketplace1155  .
        @param owner  The address of the token holder
        @return        The account's balance of the Token type requested
     */
abstract contract ANFTMarketplace1155 is INFTMarketplace1155 {

    using SafeMath for uint256;

    bytes4 public constant IID_IERC1155 = type(IERC1155).interfaceId;

    uint256 public makerFee;
    address public owner;

    SaleInfo[] fixedSaleNFT;
    SaleInfo[] auctionSaleNFT;

    mapping(address => mapping(uint256 => mapping(uint256 => FixedSale))) nftContractFixedSale;
    mapping(address => mapping(uint256 => uint256)) public nftSaleStatus;
    mapping(address => mapping(uint256 => uint256)) indexFixedSaleNFT;

    mapping(address => mapping(uint256 => Auction)) nftContractAuctionSale;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public userBidPriceOnNFT;
    mapping(address => mapping(uint256 => uint256)) indexAuctionSaleNFT;

    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public inSale;
    mapping(address => mapping(uint256 => uint256)) totalAmountInSale;

    modifier isAmountAvaible(
        address _nftContractAddress,
        uint256 _amount,
        uint256 _tokenId
    ) {
        require(
            isAmountExist(_nftContractAddress, _tokenId, _amount),
            "copies not enough"
        );
        _;
    }

    modifier isNftAlreadyInSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 0,
            "Nft already in sale"
        );
        _;
    }

    modifier isNftInFixedSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 1,
            "Nft not in fixed sale"
        );
        _;
    }

    modifier isSaleStartByOwner(address _nftContractAddress, uint256 _tokenId) {
        require(
            _ownerOf(_nftContractAddress, _tokenId),
            "You are not nft owner"
        );
        _;
    }

    modifier isSaleResetByOwner(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) {
        require(
            msg.sender ==
                nftContractFixedSale[_nftContractAddress][_tokenId][_amount]
                    .nftSeller,
            "You are not nft owner"
        );
        _;
    }

    modifier isContractApprove(address _nftContractAddress, uint256 _tokenId) {
        require(
            IERC1155(_nftContractAddress).isApprovedForAll(
                msg.sender,
                address(this)
            ),
            "Nft not approved to contract"
        );
        _;
    }

    modifier buyPriceMeetSalePrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _buyPrice,
        uint256 _amount,
        uint256 _leftAmount
    ) {
        require(
            _buyPrice >=
                (
                    nftContractFixedSale[_nftContractAddress][_tokenId][_amount]
                        .salePrice
                ) *
                    _leftAmount,
            "buy Price not enough"
        );
        _;
    }

    modifier priceGreaterThanZero(uint256 _price) {
        require(_price > 0, "Price cannot be 0");
        _;
    }

    modifier isNftInAuctionSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 2,
            "Nft not in auction sale"
        );
        _;
    }

    modifier isNftAmountInSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) {
        require(
            inSale[msg.sender][_nftContractAddress][_tokenId] >= _amount,
            "amount not in sale"
        );
        _;
    }

    modifier isAuctionOver(address _nftContractAddress, uint256 _tokenId) {
        require(
            block.timestamp >
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .auctionEnd,
            "Auction not end"
        );
        _;
    }

    modifier islatestBidGreaterPreviousOne(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _bidPrice,
        uint256 _bidPrice1
    ) {
        if (
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20 ==
            address(0)
        ) {
            require(
                _bidPrice >
                    nftContractAuctionSale[_nftContractAddress][_tokenId]
                        .nftHighestBid,
                "Bid Greater than Previous Bid"
            );
        } else {
            require(
                _bidPrice1 >
                    nftContractAuctionSale[_nftContractAddress][_tokenId]
                        .nftHighestBid,
                "Bid Greater than Previous Bid"
            );
        }

        _;
    }

    modifier isAuctionOngoing(address _nftContractAddress, uint256 _tokenId) {
        require(
            block.timestamp <
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .auctionEnd,
            "Auction end"
        );
        _;
    }

    modifier isAuctionResetByOwner(
        address _nftContractAddress,
        uint256 _tokenId
    ) {
        require(
            msg.sender ==
                nftContractAuctionSale[_nftContractAddress][_tokenId].nftSeller,
            "not nft owner"
        );
        _;
    }

    modifier isUpdatedBidGreaterPreviousOne(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateBidPrice,
        uint256 _updateBidPrice1
    ) {
        uint256 _finalBidPrice;
        if (
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20 ==
            address(0)
        ) {
            _finalBidPrice = userBidPriceOnNFT[_nftContractAddress][_tokenId][
                msg.sender
            ].add(_updateBidPrice);
        } else {
            _finalBidPrice = userBidPriceOnNFT[_nftContractAddress][_tokenId][
                msg.sender
            ].add(_updateBidPrice1);
        }
        require(
            _finalBidPrice >
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .nftHighestBid,
            "Bid Greater than Previous Bid"
        );
        _;
    }

    modifier isbidNotMakeTillNow(
        address _nftContractAddress,
        uint256 _tokenId
    ) {
        require(
            address(0) ==
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .nftHighestBidder,
            "bid make"
        );
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not a owner");
        _;
    }

    function getNftAuctionSaleDetails(
        address _nftContractAddress,
        uint256 _tokenId
    ) external view returns (Auction memory) {
        return nftContractAuctionSale[_nftContractAddress][_tokenId];
    }

    function getAuctionSaleNFT() external view returns (SaleInfo[] memory) {
        return auctionSaleNFT;
    }

    function getFixedSaleNFT() external view returns (SaleInfo[] memory) {
        return fixedSaleNFT;
    }

    function getFixedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external view returns (FixedSale memory) {
        return nftContractFixedSale[_nftContractAddress][_tokenId][_amount];
    }

    function _isTokenOrCoin(
        address _nftSeller,
        address _erc20,
        address _royaltyReciever,
        uint256 _buyAmount,
        uint256 _royalty,
        bool auction
    ) internal {
        uint256 taxAmount = (_buyAmount * makerFee) / uint256(100);
        uint256 royalty = (_buyAmount * _royalty) / uint256(100);

        uint256 userAmount = _buyAmount - (taxAmount + royalty);

        if (_erc20 != address(0)) {
            if (auction) {
                IERC20(_erc20).transfer(_nftSeller, userAmount);
                IERC20(_erc20).transfer(owner, taxAmount);
                IERC20(_erc20).transfer(_royaltyReciever, royalty);
            } else {
                AmountTransfer.tokenAmountTransfer(msg.sender,_nftSeller, _erc20, userAmount);
                AmountTransfer.tokenAmountTransfer(msg.sender,owner, _erc20, taxAmount);
                AmountTransfer.tokenAmountTransfer(msg.sender,_royaltyReciever, _erc20, royalty);
            }
        } else {
            AmountTransfer.nativeAmountTransfer(_nftSeller, userAmount);
            AmountTransfer.nativeAmountTransfer(owner, taxAmount);
            AmountTransfer.nativeAmountTransfer(_royaltyReciever, royalty);
        }
    }

    function isAmountExist(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) internal view returns (bool) {
        uint256 _balance = IERC1155(_nftContractAddress).balanceOf(
            msg.sender,
            _tokenId
        );
        return _balance >= _amount ? true : false;
    }

    function _checkFixedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _nftAmount,
        uint256 _leftAmount
    ) internal {
        address nftSeller = nftContractFixedSale[_nftContractAddress][_tokenId][
            _nftAmount
        ].nftSeller;
        inSale[nftSeller][_nftContractAddress][_tokenId] -= _leftAmount;
        totalAmountInSale[_nftContractAddress][_tokenId] -= _leftAmount;

        if (totalAmountInSale[_nftContractAddress][_tokenId] == 0) {
            delete fixedSaleNFT[
                (indexFixedSaleNFT[_nftContractAddress][_tokenId])
            ];
        }

        nftContractFixedSale[_nftContractAddress][_tokenId][_nftAmount]
            .nftBuyer = msg.sender;
    }

    function _transferNftAndPaySeller(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _bidPrice,
        address _nftBuyer
    ) internal {
        IERC1155(_nftContractAddress).safeTransferFrom(
            address(this),
            _nftBuyer,
            _tokenId,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftAmount,
            ""
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        _isTokenOrCoin(
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftSeller,
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20,
            nftContractAuctionSale[_nftContractAddress][_tokenId]
                .royaltyReciever,
            _bidPrice,
            nftContractAuctionSale[_nftContractAddress][_tokenId].royalty,
            true
        );
    }
       /**
        @notice function _storedNftAuctionDetails  .
        its a function is to store details of nft 
       */

    function _storedNftAuctionDetails(
        address _nftContractAddress,
        address _erc20,
        address _royaltyReciever,
        uint256 _tokenId,
        uint256 _auctionStart,
        uint256 _auctionEnd,
        uint256 _minPrice,
        uint256 _nftAmount,
        uint256 _royalty,
        bytes memory _data
    ) internal {
        nftContractAuctionSale[_nftContractAddress][_tokenId] = Auction(
            _auctionStart,
            _auctionEnd,
            _minPrice,
            _minPrice,
            _nftAmount,
            _royalty,
            address(0),
            msg.sender,
            _erc20,
            _royaltyReciever
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 2;

        IERC1155(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _nftAmount,
            _data
        );

        indexAuctionSaleNFT[_nftContractAddress][_tokenId] = auctionSaleNFT
            .length;
        auctionSaleNFT.push(SaleInfo(_nftContractAddress, _tokenId));

        emit NftAuctionSale(
            _nftContractAddress,
            msg.sender,
            _erc20,
            _tokenId,
            _auctionStart,
            _auctionEnd,
            _minPrice
        );
    }
       /**
        @notice function _ownerOf  .
        its a function is to check owner of nft  
       */
    function _ownerOf(address _nftContractAddress, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return
            IERC1155(_nftContractAddress).balanceOf(msg.sender, tokenId) != 0;
    }
       /**
        @notice function supportsInterface  .
        function is to check support interface for erc1155  
       */
    function isERC1155(address _nftContractAddress)
        external
        view
        returns (bool)
    {
        return IERC1155(_nftContractAddress).supportsInterface(IID_IERC1155);
    }
    /**
        @notice function _nftFixedSaleDetails  .
        function to store  _nftFixedSaleDetails  
       */
    function _nftFixedSaleDetails(
        address _nftContractAddress,
        address _erc20,
        address _royaltyReciever,
        uint256 _tokenID,
        uint256 _amount,
        uint256 _salePrice,
        uint256 _royalty,
        bytes memory _data
    ) internal {
        nftContractFixedSale[_nftContractAddress][_tokenID][
            _amount
        ] = FixedSale(
            msg.sender,
            address(0),
            _erc20,
            _royaltyReciever,
            _amount,
            _salePrice,
            _royalty
        );

        indexFixedSaleNFT[_nftContractAddress][_tokenID] = fixedSaleNFT.length;
        fixedSaleNFT.push(SaleInfo(_nftContractAddress, _tokenID));

        IERC1155(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenID,
            _amount,
            _data
        );

        inSale[msg.sender][_nftContractAddress][_tokenID] += _amount;
        totalAmountInSale[_nftContractAddress][_tokenID] += _amount;

        emit NftFixedSale(
            _nftContractAddress,
            msg.sender,
            _erc20,
            _tokenID,
            _amount,
            _salePrice,
            block.timestamp
        );
    }

    function _fixedBuy(
        address _nftContractAddress,
        uint256 _tokenID,
        uint256 _amount,
        uint256 _nftAmount,
        uint256 _leftAmount,
        bytes memory _data
    ) internal {
        IERC1155(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenID,
            _leftAmount,
            _data
        );

        nftContractFixedSale[_nftContractAddress][_tokenID][_nftAmount]
            .amount -= _leftAmount;

        _checkFixedSale(_nftContractAddress, _tokenID, _nftAmount, _leftAmount);

        _isTokenOrCoin(
            nftContractFixedSale[_nftContractAddress][_tokenID][_nftAmount]
                .nftSeller,
            nftContractFixedSale[_nftContractAddress][_tokenID][_nftAmount]
                .erc20,
            nftContractFixedSale[_nftContractAddress][_tokenID][_nftAmount]
                .royaltyReciever,
            nftContractFixedSale[_nftContractAddress][_tokenID][_nftAmount]
                .salePrice * _leftAmount,
            nftContractFixedSale[_nftContractAddress][_tokenID][_nftAmount]
                .royalty,
            false
        );

        emit NftBuyFromFixedSale(
            _nftContractAddress,
            msg.sender,
            _tokenID,
            _amount,
            _nftAmount
        );
    }
}
