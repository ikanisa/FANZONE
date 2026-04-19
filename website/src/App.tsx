import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';

// Pages placeholders that we will create
import Home from './pages/Home';
import Overview from './pages/Overview';
import Coverage from './pages/Coverage';
import FetToken from './pages/FetToken';
import GuestAuth from './pages/GuestAuth';
import Rewards from './pages/Rewards';
import FAQ from './pages/FAQ';
import Privacy from './pages/Privacy';
import Terms from './pages/Terms';
import Contact from './pages/Contact';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="overview" element={<Overview />} />
        <Route path="coverage" element={<Coverage />} />
        <Route path="fet" element={<FetToken />} />
        <Route path="guest-auth" element={<GuestAuth />} />
        <Route path="rewards" element={<Rewards />} />
        <Route path="faq" element={<FAQ />} />
        <Route path="privacy" element={<Privacy />} />
        <Route path="terms" element={<Terms />} />
        <Route path="contact" element={<Contact />} />
      </Route>
    </Routes>
  );
}

export default App;
