// Zarządzanie ekranami
class ZarządcaEkranów {
    constructor() {
        this.ekranyMapa = {
            'logowanie': document.getElementById('ekranLogowania'),
            'domowy': document.getElementById('ekranDomowy'),
            'alarmy': document.getElementById('ekranAlarmy'),
            'czat': document.getElementById('ekranCzat'),
            'dyżury': document.getElementById('ekranDyżury'),
        };
        this.aktywnyEkran = 'logowanie';
    }

    pokaż(nazwaEkranu) {
        // Ukryj wszystkie ekrany
        Object.values(this.ekranyMapa).forEach(ekran => {
            ekran.classList.remove('aktywny');
        });

        // Pokaż wybrany ekran
        if (this.ekranyMapa[nazwaEkranu]) {
            this.ekranyMapa[nazwaEkranu].classList.add('aktywny');
            this.aktywnyEkran = nazwaEkranu;
        }
    }
}

// Serwis autentykacji
class SerwisAutentykacji {
    constructor() {
        this.zalogowanyUżytkownik = null;
    }

    zaloguj(login, hasło) {
        // Walidacja prosta
        if (!login || !hasło) {
            return { sukces: false, komunikat: 'Wypełnij wszystkie pola' };
        }

        if (hasło.length < 6) {
            return { sukces: false, komunikat: 'Hasło musi mieć co najmniej 6 znaków' };
        }

        // Symulacja logowania
        this.zalogowanyUżytkownik = {
            login: login,
            data_logowania: new Date()
        };

        return { sukces: true, komunikat: 'Logowanie pomyślne' };
    }

    wyloguj() {
        this.zalogowanyUżytkownik = null;
    }

    czyZalogowany() {
        return this.zalogowanyUżytkownik !== null;
    }
}

// Inicjalizacja aplikacji
const zarządcaEkranów = new ZarządcaEkranów();
const serwisAutentykacji = new SerwisAutentykacji();

// Elementy interfejsu
const loginInput = document.getElementById('loginInput');
const hasloInput = document.getElementById('hasloInput');
const przyciskLogowania = document.getElementById('przyciskLogowania');
const bladLogowania = document.getElementById('bladLogowania');
const przyciskWylogowania = document.getElementById('przyciskWylogowania');

// Pozycje menu
const pozycjeMenu = document.querySelectorAll('.pozycja-menu');
const przyciskiPowrotu = {
    'alarmy': document.getElementById('powrotZAlarmy'),
    'czat': document.getElementById('powrotZCzatu'),
    'dyżury': document.getElementById('powrotZDyżurow'),
};

// Obsługa logowania
przyciskLogowania.addEventListener('click', () => {
    const login = loginInput.value;
    const hasło = hasloInput.value;

    const wynik = serwisAutentykacji.zaloguj(login, hasło);

    if (wynik.sukces) {
        bladLogowania.classList.remove('widoczny');
        zarządcaEkranów.pokaż('domowy');
        loginInput.value = '';
        hasloInput.value = '';
    } else {
        bladLogowania.textContent = wynik.komunikat;
        bladLogowania.classList.add('widoczny');
    }
});

// Obsługa Enter w formularzach
[loginInput, hasloInput].forEach(input => {
    input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            przyciskLogowania.click();
        }
    });
});

// Obsługa wylogowania
przyciskWylogowania.addEventListener('click', () => {
    serwisAutentykacji.wyloguj();
    zarządcaEkranów.pokaż('logowanie');
});

// Obsługa pozycji menu
pozycjeMenu.forEach(pozycja => {
    pozycja.addEventListener('click', () => {
        const akcja = pozycja.getAttribute('data-akcja');

        switch (akcja) {
            case 'alarmy':
                zarządcaEkranów.pokaż('alarmy');
                break;
            case 'czat':
                zarządcaEkranów.pokaż('czat');
                break;
            case 'dyżury':
                zarządcaEkranów.pokaż('dyżury');
                break;
        }
    });
});

// Obsługa przycisków powrotu
Object.values(przyciskiPowrotu).forEach(przycisk => {
    if (przycisk) {
        przycisk.addEventListener('click', () => {
            zarządcaEkranów.pokaż('domowy');
        });
    }
});

// Obsługa czatu
const wejscieCzatu = document.getElementById('wejscieCzatu');
const przyciskWyslijWiadomosc = document.getElementById('przyciskWyslijWiadomosc');
const listaWiadomosci = document.getElementById('listaWiadomosci');

przyciskWyslijWiadomosc.addEventListener('click', () => {
    wyslijWiadomosc();
});

wejscieCzatu.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        wyslijWiadomosc();
    }
});

function wyslijWiadomosc() {
    const wiadomosc = wejscieCzatu.value.trim();

    if (wiadomosc === '') {
        return;
    }

    // Dodaj wiadomość użytkownika
    const elementWiadomosci = document.createElement('div');
    elementWiadomosci.className = 'wiadomosc wlasna';
    elementWiadomosci.innerHTML = `
        <div>
            <p>${wiadomosc}</p>
            <span class="czas-wiadomosci">${new Date().toLocaleTimeString('pl-PL', { hour: '2-digit', minute: '2-digit' })}</span>
        </div>
    `;
    listaWiadomosci.appendChild(elementWiadomosci);

    // Wyczyść pole wejścia
    wejscieCzatu.value = '';

    // Przewiń do dołu
    listaWiadomosci.scrollTop = listaWiadomosci.scrollHeight;

    // Symulacja odpowiedzi
    setTimeout(() => {
        const odpowiedź = document.createElement('div');
        odpowiedź.className = 'wiadomosc inna';
        odpowiedź.innerHTML = `
            <div>
                <p>Kolegium: Wiadomość otrzymana!</p>
                <span class="czas-wiadomosci">${new Date().toLocaleTimeString('pl-PL', { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
        `;
        listaWiadomosci.appendChild(odpowiedź);
        listaWiadomosci.scrollTop = listaWiadomosci.scrollHeight;
    }, 500);
}

// Inicjalizacja - wyświetl ekran logowania
zarządcaEkranów.pokaż('logowanie');
