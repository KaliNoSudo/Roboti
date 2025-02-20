document.querySelectorAll('.add-to-cart').forEach(button => {
    button.addEventListener('click', function() {
        const productId = this.parentElement.getAttribute('data-productid');
        const productName = this.parentElement.textContent.trim().split(' ')[0];
        
        const cartItem = document.createElement('li');
        cartItem.innerHTML = `${productName} <button class="remove-from-cart">Remove</button>`;
        cartItem.setAttribute('data-productid', productId);
        
        document.getElementById('cart').appendChild(cartItem);
    });
});