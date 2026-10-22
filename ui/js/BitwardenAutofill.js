// Bitwarden In-Page Autofill & Login Detector for Focus Browser

(function() {
    window.__focusBitwardenInit = function(credentialsJson, isUnlocked, isInstalled) {
        window.__focusCreds = [];
        try {
            window.__focusCreds = JSON.parse(credentialsJson) || [];
        } catch(e) {
            window.__focusCreds = [];
        }
        window.__focusBwUnlocked = isUnlocked;
        window.__focusBwInstalled = isInstalled;

        // Remove old popup if exists
        var existingPopup = document.getElementById('focus-bw-autofill-popup');
        if (existingPopup) existingPopup.remove();

        function findForms() {
            var passInputs = document.querySelectorAll('input[type="password"]');
            passInputs.forEach(function(passInput) {
                if (passInput.__focusWatched) return;
                passInput.__focusWatched = true;

                // Find corresponding username input
                var form = passInput.form || passInput.closest('form');
                var userInput = null;

                if (form) {
                    userInput = form.querySelector('input[type="email"], input[type="text"][name*="user" i], input[type="text"][name*="login" i], input[type="text"][name*="email" i], input[type="text"][autocomplete*="username" i], input[type="text"]');
                }
                if (!userInput) {
                    var container = passInput.parentElement ? passInput.parentElement.parentElement : null;
                    if (container) {
                        userInput = container.querySelector('input[type="text"], input[type="email"]');
                    }
                }

                // Attach focus handlers
                function onFocus(e) {
                    showAutofillPopup(e.target, userInput, passInput);
                }

                passInput.addEventListener('focus', onFocus);
                if (userInput && !userInput.__focusWatched) {
                    userInput.__focusWatched = true;
                    userInput.addEventListener('focus', onFocus);
                }

                // Intercept submission on Enter in password field
                passInput.addEventListener('keydown', function(e) {
                    if (e.key === 'Enter') {
                        var uVal = userInput ? userInput.value : '';
                        var pVal = passInput.value;
                        if (pVal && pVal.length > 0 && uVal && uVal.length > 0) {
                            console.log('[FOCUS_BITWARDEN_SAVE]:' + JSON.stringify({
                                url: window.location.href,
                                username: uVal,
                                password: pVal
                            }));
                        }
                    }
                });

                // Intercept form submit
                if (form && !form.__focusSubmitWatched) {
                    form.__focusSubmitWatched = true;
                    form.addEventListener('submit', function() {
                        var uVal = userInput ? userInput.value : '';
                        var pVal = passInput.value;
                        if (pVal && pVal.length > 0 && uVal && uVal.length > 0) {
                            console.log('[FOCUS_BITWARDEN_SAVE]:' + JSON.stringify({
                                url: window.location.href,
                                username: uVal,
                                password: pVal
                            }));
                        }
                    });
                }
            });
        }

        function showAutofillPopup(targetInput, userInput, passInput) {
            var popup = document.getElementById('focus-bw-autofill-popup');
            if (popup) popup.remove();

            var rect = targetInput.getBoundingClientRect();
            popup = document.createElement('div');
            popup.id = 'focus-bw-autofill-popup';
            popup.style.position = 'fixed';
            popup.style.top = (rect.bottom + 4) + 'px';
            popup.style.left = rect.left + 'px';
            popup.style.minWidth = Math.max(220, rect.width) + 'px';
            popup.style.maxWidth = '360px';
            popup.style.backgroundColor = '#18181b';
            popup.style.color = '#f4f4f5';
            popup.style.border = '1px solid #3f3f46';
            popup.style.borderRadius = '8px';
            popup.style.boxShadow = '0 10px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5)';
            popup.style.zIndex = '2147483647';
            popup.style.fontFamily = 'Inter, -apple-system, BlinkMacSystemFont, sans-serif';
            popup.style.fontSize = '12px';
            popup.style.overflow = 'hidden';

            var listHtml = '';
            var creds = window.__focusCreds || [];

            if (creds.length > 0) {
                creds.forEach(function(cred, idx) {
                    listHtml += '<div class="focus-bw-item" data-idx="' + idx + '" style="display:flex;align-items:center;padding:10px 12px;cursor:pointer;gap:10px;border-bottom:1px solid #27272a;transition:background 0.15s;">' +
                        '<div style="font-size:16px;">🔑</div>' +
                        '<div style="flex:1;overflow:hidden;">' +
                            '<div style="font-weight:600;color:#fafafa;text-overflow:ellipsis;overflow:hidden;white-space:nowrap;">' + (cred.username || 'Sem usuário') + '</div>' +
                            '<div style="font-size:10px;color:#a1a1aa;">•••••••• • ' + (cred.name || cred.source || 'Bitwarden') + '</div>' +
                        '</div>' +
                        '<div style="font-size:9px;background:#27272a;padding:2px 6px;border-radius:4px;color:#71717a;">Preencher</div>' +
                    '</div>';
                });
            } else if (!window.__focusBwUnlocked) {
                listHtml += '<div class="focus-bw-unlock" style="display:flex;align-items:center;padding:12px;cursor:pointer;gap:10px;">' +
                    '<div style="font-size:16px;">🔒</div>' +
                    '<div style="flex:1;">' +
                        '<div style="font-weight:600;color:#60a5fa;">Desbloquear Bitwarden</div>' +
                        '<div style="font-size:10px;color:#a1a1aa;">Clique para abrir suas credenciais</div>' +
                    '</div>' +
                '</div>';
            } else {
                listHtml += '<div style="padding:10px 12px;color:#a1a1aa;font-size:11px;">Nenhuma senha encontrada para este site no Bitwarden.</div>';
            }

            popup.innerHTML = listHtml;
            document.body.appendChild(popup);

            // Click handling
            popup.querySelectorAll('.focus-bw-item').forEach(function(el) {
                el.addEventListener('mouseenter', function() { el.style.backgroundColor = '#27272a'; });
                el.addEventListener('mouseleave', function() { el.style.backgroundColor = 'transparent'; });
                el.addEventListener('mousedown', function(e) {
                    e.preventDefault();
                    var idx = parseInt(el.getAttribute('data-idx'));
                    var cred = window.__focusCreds[idx];
                    if (cred) {
                        if (userInput) {
                            userInput.value = cred.username || '';
                            userInput.dispatchEvent(new Event('input', { bubbles: true }));
                            userInput.dispatchEvent(new Event('change', { bubbles: true }));
                        }
                        if (passInput) {
                            passInput.value = cred.password || '';
                            passInput.dispatchEvent(new Event('input', { bubbles: true }));
                            passInput.dispatchEvent(new Event('change', { bubbles: true }));
                        }
                    }
                    popup.remove();
                });
            });

            var unlockBtn = popup.querySelector('.focus-bw-unlock');
            if (unlockBtn) {
                unlockBtn.addEventListener('mouseenter', function() { unlockBtn.style.backgroundColor = '#27272a'; });
                unlockBtn.addEventListener('mouseleave', function() { unlockBtn.style.backgroundColor = 'transparent'; });
                unlockBtn.addEventListener('mousedown', function(e) {
                    e.preventDefault();
                    console.log('[FOCUS_BITWARDEN_UNLOCK]');
                    popup.remove();
                });
            }

            // Click outside to dismiss
            function onDocClick(ev) {
                if (!popup.contains(ev.target) && ev.target !== targetInput) {
                    popup.remove();
                    document.removeEventListener('mousedown', onDocClick);
                }
            }
            setTimeout(function() {
                document.addEventListener('mousedown', onDocClick);
            }, 50);
        }

        findForms();
        // Periodically check for dynamically rendered login forms (SPA/React/Vue)
        if (!window.__focusFormInterval) {
            window.__focusFormInterval = setInterval(findForms, 1500);
        }
    };
})();
