(() => {
  const form = document.getElementById('productForm');

  if (form) {
    const nameInput = document.getElementById('ProductName');
    const descriptionInput = document.getElementById('Description');
    const nameCounter = document.getElementById('nameCounter');
    const descriptionCounter = document.getElementById('descriptionCounter');

    const updateCounters = () => {
      if (nameCounter) nameCounter.textContent = `${nameInput.value.length}/200`;
      if (descriptionCounter) {
        descriptionCounter.textContent = `${descriptionInput.value.length}/5000`;
      }
    };

    const setError = (fieldName, message) => {
      const errorElement = document.querySelector(`[data-error-for="${fieldName}"]`);
      const input = document.getElementById(fieldName);
      if (errorElement) errorElement.textContent = message || '';
      if (input) input.classList.toggle('invalid', Boolean(message));
    };

    const validate = () => {
      let firstInvalid = null;
      const fail = (fieldName, message) => {
        setError(fieldName, message);
        if (!firstInvalid) firstInvalid = document.getElementById(fieldName);
      };

      if (!document.getElementById('CategoryID').value) {
        fail('CategoryID', 'Vui lòng chọn danh mục lá.');
      } else {
        setError('CategoryID', '');
      }

      const name = nameInput.value.trim();
      if (!name) {
        fail('ProductName', 'Tên sản phẩm không được để trống.');
      } else if (name.length > 200) {
        fail('ProductName', `Tên sản phẩm tối đa 200 ký tự (hiện tại ${name.length}).`);
      } else {
        setError('ProductName', '');
      }

      if (descriptionInput.value.trim().length > 5000) {
        fail('Description', `Mô tả tối đa 5.000 ký tự (hiện tại ${descriptionInput.value.trim().length}).`);
      } else {
        setError('Description', '');
      }

      const status = document.getElementById('ProductStatus').value;
      if (!['ACTIVE', 'HIDDEN', 'INACTIVE'].includes(status)) {
        fail('ProductStatus', 'Trạng thái không hợp lệ.');
      } else {
        setError('ProductStatus', '');
      }

      if (firstInvalid) {
        firstInvalid.focus({ preventScroll: false });
        firstInvalid.scrollIntoView({ block: 'center', behavior: 'smooth' });
      }
      return !firstInvalid;
    };

    updateCounters();
    nameInput.addEventListener('input', () => {
      updateCounters();
      setError('ProductName', '');
    });
    descriptionInput.addEventListener('input', () => {
      updateCounters();
      setError('Description', '');
    });
    document.getElementById('CategoryID').addEventListener('change', () => setError('CategoryID', ''));
    document.getElementById('ProductStatus').addEventListener('change', () => setError('ProductStatus', ''));

    form.addEventListener('submit', (event) => {
      if (!validate()) {
        event.preventDefault();
        return;
      }
      const submitButton = form.querySelector('button[type="submit"]');
      if (submitButton) {
        submitButton.disabled = true;
        submitButton.textContent = 'Đang lưu…';
      }
    });
  }

  /* ----------------------------- Modal xóa ----------------------------- */
  const modal = document.getElementById('deleteModal');
  const deleteForm = document.getElementById('deleteForm');
  const deleteName = document.getElementById('deleteName');
  const deleteId = document.getElementById('deleteId');
  let lastFocused = null;

  const openModal = (id, name) => {
    if (!modal || !deleteForm) return;
    lastFocused = document.activeElement;
    deleteName.textContent = name;
    deleteId.textContent = `#${id}`;
    deleteForm.action = `${deleteForm.dataset.actionBase || '/products/'}${id}/delete`;
    modal.hidden = false;
    document.body.style.overflow = 'hidden';
    const cancelButton = modal.querySelector('[data-close-modal]');
    if (cancelButton) cancelButton.focus();
  };

  const closeModal = () => {
    if (!modal || modal.hidden) return;
    modal.hidden = true;
    document.body.style.overflow = '';
    if (lastFocused) lastFocused.focus();
  };

  document.querySelectorAll('[data-delete-id]').forEach((button) => {
    button.addEventListener('click', () => {
      openModal(button.dataset.deleteId, button.dataset.deleteName);
    });
  });

  if (modal) {
    modal.querySelectorAll('[data-close-modal]').forEach((button) => {
      button.addEventListener('click', closeModal);
    });
    modal.addEventListener('click', (event) => {
      if (event.target === modal) closeModal();
    });
  }

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeModal();
  });

  /* ------------------- Xác nhận trước khi gửi (gỡ, từ chối) ------------------- */
  document.querySelectorAll('form[data-confirm]').forEach((f) => {
    f.addEventListener('submit', (event) => {
      if (!window.confirm(f.dataset.confirm)) event.preventDefault();
    });
  });

  /* --------------- Đăng ký: chỉ hiện ô mã số thuế khi chọn Người bán --------------- */
  const registerForm = document.getElementById('registerForm');
  if (registerForm) {
    const sync = () => {
      const role = registerForm.querySelector('input[name="role"]:checked')?.value;
      registerForm.querySelectorAll('.seller-only').forEach((el) => {
        el.hidden = role !== 'seller';
      });
    };
    registerForm.querySelectorAll('input[name="role"]').forEach((r) => r.addEventListener('change', sync));
    sync();
  }
})();
